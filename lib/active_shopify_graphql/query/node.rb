# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Query
    # Abstract base class for all GraphQL query nodes.
    # Provides shared attributes and helper methods for node rendering.
    #
    # Subclasses:
    #   - Node::Field - Simple and nested fields
    #   - Node::Singular - Singular associations (has_one)
    #   - Node::Connection - Collection associations using nodes pattern
    #   - Node::Fragment - Fragment definitions
    #   - Node::Raw - Raw GraphQL strings
    #   - Node::SingleRecord - Single record queries by ID
    #   - Node::CurrentCustomer - ID-less queries (Customer Account API)
    #   - Node::Collection - Collection queries with optional pagination
    #   - Node::NestedConnection - Nested connection queries
    #   - Node::RootConnection - Root-level connection queries
    class Node
      # Shared constants for query formatting
      PAGE_INFO_FIELDS = "pageInfo { hasNextPage hasPreviousPage startCursor endCursor }"
      STRING_KEYS_NEEDING_QUOTES = %i[query after before].freeze
      attr_reader :name, :alias_name, :arguments, :children

      # @param name [String] The field name (e.g., 'id', 'displayName', 'orders')
      # @param alias_name [String] Optional field alias (e.g., 'myAlias' for 'myAlias: fieldName')
      # @param arguments [Hash] Field arguments (e.g., { first: 10, sortKey: 'CREATED_AT' })
      # @param children [Array<Query::Node>] Child nodes for nested structures
      def initialize(name:, alias_name: nil, arguments: {}, children: [])
        @name = name
        @alias_name = alias_name
        @arguments = arguments
        @children = children
      end

      # Add a child node
      def add_child(node)
        @children << node
        node
      end

      # Check if node has children
      def has_children?
        @children.any?
      end

      # Convert node to GraphQL string - must be implemented by subclasses
      def to_s
        raise NotImplementedError, "#{self.class} must implement #to_s"
      end

      private

      def field_name_with_alias
        @alias_name ? "#{@alias_name}: #{@name}" : @name
      end

      def format_arguments
        return "" if @arguments.empty?

        # Filter out internal arguments (like :on for fragments)
        graphql_args = @arguments.except(:on)
        return "" if graphql_args.empty?

        args = graphql_args.map do |key, value|
          graphql_key = key.to_s.camelize(:lower)
          formatted_value = format_argument_value(key, value)
          "#{graphql_key}: #{formatted_value}"
        end

        "(#{args.join(', ')})"
      end

      def format_argument_value(key, value)
        case value
        when String
          # Keys that need quoted string values
          if %i[namespace key query].include?(key.to_sym)
            "\"#{value}\""
          else
            value
          end
        when Symbol
          value.to_s
        else
          value
        end
      end

      def render_children
        @children.map(&:to_s)
      end
    end
  end
end
