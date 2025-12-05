# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Handles GraphQL query building for single records and collections
  class RecordQuery
    attr_reader :graphql_type, :loader_class

    def initialize(graphql_type:, loader_class:, defined_attributes:, model_class:, included_connections:, fragment_generator:, fragment_name_proc:)
      @graphql_type = graphql_type
      @loader_class = loader_class
      @fragment_proc = fragment_generator
      # Store data needed to create Fragment instances
      @defined_attributes = defined_attributes
      @model_class = model_class
      @included_connections = included_connections
      @fragment_name_proc = fragment_name_proc
    end

    # Override this to define the query name (can accept model_type for customization)
    def query_name(model_type = nil)
      type = model_type || @graphql_type
      type.downcase
    end

    # Override this to define the fragment name (can accept model_type for customization)
    def fragment_name(model_type = nil)
      type = model_type || @graphql_type
      "#{type}Fragment"
    end

    # Builds the complete GraphQL query using the fragment
    def graphql_query(model_type = nil)
      type = model_type || @graphql_type
      query_name_value = query_name(type)
      fragment_name_value = fragment_name(type)

      if ActiveShopifyGraphQL.configuration.compact_queries
        "#{@fragment_proc.call} query get#{type}($id: ID!) { #{query_name_value}(id: $id) { ...#{fragment_name_value} } }"
      else
        <<~GRAPHQL
          #{@fragment_proc.call}
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
      type = model_type || @graphql_type
      query_name_value = query_name(type).pluralize
      fragment_name_value = fragment_name(type)

      if ActiveShopifyGraphQL.configuration.compact_queries
        "#{@fragment_proc.call} query get#{type.pluralize}($query: String, $first: Int!) { #{query_name_value}(query: $query, first: $first) { nodes { ...#{fragment_name_value} } } }"
      else
        <<~GRAPHQL
          #{@fragment_proc.call}
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
  end
end
