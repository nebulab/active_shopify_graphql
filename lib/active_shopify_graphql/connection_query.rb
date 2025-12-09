# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Handles GraphQL query building for connections (both root-level and nested)
  class ConnectionQuery
    attr_reader :graphql_type, :loader_class

    def initialize(graphql_type:, loader_class:, defined_attributes:, model_class:, included_connections:)
      @graphql_type = graphql_type
      @loader_class = loader_class
      # Store data needed to create Fragment instances
      @defined_attributes = defined_attributes
      @model_class = model_class
      @included_connections = included_connections
    end

    # Build a complete query structure with optional parent and field wrapping
    def build_query_structure(field_query:, query_signature: "", parent_query: nil, connection_type: :connection)
      compact = ActiveShopifyGraphQL.configuration.compact_queries
      fragment_fields = create_fragment.fields_from_attributes

      if parent_query
        # Nested query with parent
        inner_query = connection_type == :singular ? build_singular_query(field_query, fragment_fields) : build_connection_query(field_query, fragment_fields)

        if compact
          "query#{query_signature} { #{parent_query} { #{inner_query} } }"
        else
          build_nested_multiline_query(query_signature, parent_query, inner_query)
        end
      elsif connection_type == :singular
        # Root-level query
        build_root_singular_query(query_signature, field_query, fragment_fields)
      else
        build_root_connection_query(query_signature, field_query, fragment_fields)
      end
    end

    # Build GraphQL query for nested connection (field on parent object)
    def nested_connection_graphql_query(connection_field_name, variables, parent, connection_config = nil)
      # Get the parent's GraphQL type
      parent_type = parent.class.graphql_type_for_loader(@loader_class)
      parent_query_name = parent_type.downcase

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

      # Build the complete query structure
      build_query_structure(
        query_signature: query_signature,
        parent_query: "#{parent_query_name}(id: $id)",
        field_query: "#{connection_field_name}#{field_signature}",
        connection_type: connection_type
      )
    end

    # Build GraphQL query for connection with dynamic parameters
    def connection_graphql_query(query_name, variables, connection_config = nil)
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

      # Build the complete query structure
      build_query_structure(
        query_signature: "",
        parent_query: nil,
        field_query: "#{query_name}#{field_signature}",
        connection_type: connection_type
      )
    end

    private

    # Create a Fragment instance with explicit parameters
    def create_fragment
      Fragment.new(
        graphql_type: @graphql_type,
        loader_class: @loader_class,
        defined_attributes: @defined_attributes,
        model_class: @model_class,
        included_connections: @included_connections
      )
    end

    # Build a query wrapping fields in connection structure (edges/node)
    def build_connection_query(field_signature, fragment_fields)
      compact = ActiveShopifyGraphQL.configuration.compact_queries

      if compact
        "#{field_signature} { edges { node { #{fragment_fields} } } }"
      else
        indent = "          "
        build_multiline_query(field_signature, fragment_fields, indent, include_edges: true)
      end
    end

    # Build a query wrapping fields in singular structure (no edges/node)
    def build_singular_query(field_signature, fragment_fields)
      compact = ActiveShopifyGraphQL.configuration.compact_queries

      if compact
        "#{field_signature} { #{fragment_fields} }"
      else
        indent = "          "
        build_multiline_query(field_signature, fragment_fields, indent, include_edges: false)
      end
    end

    # Build multiline query structure for fields
    def build_multiline_query(field_signature, fragment_fields, indent, include_edges:)
      if include_edges
        "#{field_signature} {\n#{indent}edges {\n#{indent}  node {\n#{indent}    #{fragment_fields}\n#{indent}  }\n#{indent}}\n        }"
      else
        "#{field_signature} {\n#{indent}  #{fragment_fields}\n        }"
      end
    end

    # Build nested multiline query with parent
    def build_nested_multiline_query(query_signature, parent_query, inner_query)
      "query#{query_signature} {\n      #{parent_query} {\n        #{inner_query}\n      }\n    }"
    end

    # Build root-level singular query
    def build_root_singular_query(query_signature, field_query, fragment_fields)
      compact = ActiveShopifyGraphQL.configuration.compact_queries

      if compact
        "query#{query_signature} { #{field_query} { #{fragment_fields} } }"
      else
        "query#{query_signature} {\n      #{field_query} {\n        #{fragment_fields}\n      }\n    }"
      end
    end

    # Build root-level connection query
    def build_root_connection_query(query_signature, field_query, fragment_fields)
      compact = ActiveShopifyGraphQL.configuration.compact_queries

      if compact
        "query#{query_signature} { #{field_query} { edges { node { #{fragment_fields} } } } }"
      else
        "query#{query_signature} {\n      #{field_query} {\n        edges {\n          node {\n            #{fragment_fields}\n          }\n        }\n      }\n    }"
      end
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
