# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Handles GraphQL query building for single records, collections, and connections
  class Query
    attr_reader :loader

    def initialize(loader)
      @loader = loader
    end

    # Override this to define the query name (can accept model_type for customization)
    def query_name(model_type = nil)
      type = model_type || @loader.graphql_type
      type.downcase
    end

    # Override this to define the fragment name (can accept model_type for customization)
    def fragment_name(model_type = nil)
      type = model_type || @loader.graphql_type
      "#{type}Fragment"
    end

    # Builds the complete GraphQL query using the fragment
    def graphql_query(model_type = nil)
      type = model_type || @loader.graphql_type
      query_name_value = query_name(type)
      fragment_name_value = fragment_name(type)

      if ActiveShopifyGraphQL.configuration.compact_queries
        "#{@loader.fragment} query get#{type}($id: ID!) { #{query_name_value}(id: $id) { ...#{fragment_name_value} } }"
      else
        <<~GRAPHQL
          #{@loader.fragment}
          query get#{type}($id: ID!) {
            #{query_name_value}(id: $id) {
              ...#{fragment_name_value}
            }
          }
        GRAPHQL
      end
    end

    # Builds the GraphQL query for collections
    # @param model_type [String] The model type (optional, uses class graphql_type if not provided)
    # @return [String] The GraphQL query string
    def collection_graphql_query(model_type = nil)
      type = model_type || @loader.class.graphql_type
      query_name_value = query_name(type).pluralize
      fragment_name_value = fragment_name(type)

      if ActiveShopifyGraphQL.configuration.compact_queries
        "#{@loader.fragment} query get#{type.pluralize}($query: String, $first: Int!) { #{query_name_value}(query: $query, first: $first) { nodes { ...#{fragment_name_value} } } }"
      else
        <<~GRAPHQL
          #{@loader.fragment}
          query get#{type.pluralize}($query: String, $first: Int!) {
            #{query_name_value}(query: $query, first: $first) {
              nodes {
                ...#{fragment_name_value}
              }
            }
          }
        GRAPHQL
      end
    end

    # Build GraphQL query for nested connection (field on parent object)
    def nested_connection_graphql_query(connection_field_name, variables, parent, connection_config = nil)
      # Get the parent's GraphQL type
      parent_type = parent.class.graphql_type_for_loader(@loader.class)
      parent_query_name = parent_type.downcase

      # Get just the fragment fields without the fragment wrapper
      fragment_fields = Fragment.new(@loader).fields_from_attributes

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
      fragment_fields = Fragment.new(@loader).fields_from_attributes

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
