# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Handles GraphQL query building for connections (both root-level and nested)
  class ConnectionQuery
    attr_reader :graphql_type, :loader_class

    def initialize(graphql_type:, loader_class:, defined_attributes:, model_class:, included_connections:, fragment_name_proc:)
      @graphql_type = graphql_type
      @loader_class = loader_class
      # Store data needed to create Fragment instances
      @defined_attributes = defined_attributes
      @model_class = model_class
      @included_connections = included_connections
      @fragment_name_proc = fragment_name_proc
    end

    # Build GraphQL query for nested connection (field on parent object)
    def nested_connection_graphql_query(connection_field_name, variables, parent, connection_config = nil)
      # Get the parent's GraphQL type
      parent_type = parent.class.graphql_type_for_loader(@loader_class)
      parent_query_name = parent_type.downcase

      # Get just the fragment fields without the fragment wrapper
      fragment_fields = create_fragment.fields_from_attributes

      # Only the parent ID is passed as a variable; all other arguments are inline
      query_params = ["$id: ID!"]
      field_params = []

      # Process all variables as passthrough inline values
      variables.each do |key, value|
        next if value.nil?

        # Convert Ruby snake_case to GraphQL camelCase
        graphql_key = key.to_s.camelize(:lower)

        # Format value for inline use in the GraphQL query
        formatted_value = format_inline_value(key, value)

        field_params << "#{graphql_key}: #{formatted_value}"
      end

      query_signature = "(#{query_params.join(', ')})"
      field_signature = field_params.empty? ? "" : "(#{field_params.join(', ')})"

      connection_type = connection_config&.dig(:type) || :connection

      if connection_type == :singular
        if ActiveShopifyGraphQL.configuration.compact_queries
          "query#{query_signature} { #{parent_query_name}(id: $id) { #{connection_field_name}#{field_signature} { #{fragment_fields} } } }"
        else
          <<~GRAPHQL
            query#{query_signature} {
              #{parent_query_name}(id: $id) {
                #{connection_field_name}#{field_signature} {
                  #{fragment_fields}
                }
              }
            }
          GRAPHQL
        end
      elsif ActiveShopifyGraphQL.configuration.compact_queries
        "query#{query_signature} { #{parent_query_name}(id: $id) { #{connection_field_name}#{field_signature} { edges { node { #{fragment_fields} } } } } }"
      else
        <<~GRAPHQL
          query#{query_signature} {
            #{parent_query_name}(id: $id) {
              #{connection_field_name}#{field_signature} {
                edges {
                  node {
                    #{fragment_fields}
                  }
                }
              }
            }
          }
        GRAPHQL
      end
    end

    # Build GraphQL query for connection with dynamic parameters
    def connection_graphql_query(query_name, variables, connection_config = nil)
      # Get just the fragment fields without the fragment wrapper
      fragment_fields = create_fragment.fields_from_attributes

      # All arguments are passed as inline values (no GraphQL variables needed)
      field_params = []

      # Process all variables as passthrough inline values
      variables.each do |key, value|
        next if value.nil?

        # Convert Ruby snake_case to GraphQL camelCase
        graphql_key = key.to_s.camelize(:lower)

        # Format value for inline use in the GraphQL query
        formatted_value = format_inline_value(key, value)

        field_params << "#{graphql_key}: #{formatted_value}"
      end

      field_signature = field_params.empty? ? "" : "(#{field_params.join(', ')})"

      connection_type = connection_config&.dig(:type) || :connection

      if connection_type == :singular
        if ActiveShopifyGraphQL.configuration.compact_queries
          "query { #{query_name}#{field_signature} { #{fragment_fields} } }"
        else
          <<~GRAPHQL
            query {
              #{query_name}#{field_signature} {
                #{fragment_fields}
              }
            }
          GRAPHQL
        end
      elsif ActiveShopifyGraphQL.configuration.compact_queries
        "query { #{query_name}#{field_signature} { edges { node { #{fragment_fields} } } } }"
      else
        <<~GRAPHQL
          query {
            #{query_name}#{field_signature} {
              edges {
                node {
                  #{fragment_fields}
                }
              }
            }
          }
        GRAPHQL
      end
    end

    private

    # Create a Fragment instance with explicit parameters
    def create_fragment
      Fragment.new(
        graphql_type: @graphql_type,
        loader_class: @loader_class,
        defined_attributes: @defined_attributes,
        model_class: @model_class,
        included_connections: @included_connections,
        fragment_name_proc: @fragment_name_proc
      )
    end

    # Format value for inline use in GraphQL query
    def format_inline_value(key, value)
      case value
      when Integer
        value.to_s
      when TrueClass, FalseClass
        value.to_s
      when String
        # The 'query' parameter needs quoted strings for search syntax
        if key.to_sym == :query
          "\"#{value}\""
        else
          # Other string values (like enum sort keys) don't need quotes
          value
        end
      else
        value.to_s
      end
    end
  end
end
