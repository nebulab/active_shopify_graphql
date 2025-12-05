# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Handles GraphQL query building for single records and collections
  class RecordQuery
    attr_reader :graphql_type, :loader_class

    def initialize(graphql_type:, loader_class:, defined_attributes:, model_class:, included_connections:, fragment:)
      @graphql_type = graphql_type
      @loader_class = loader_class
      @fragment = fragment
      # Store data needed to create Fragment instances
      @defined_attributes = defined_attributes
      @model_class = model_class
      @included_connections = included_connections
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

      compact = ActiveShopifyGraphQL.configuration.compact_queries
      fragment_string = @fragment.to_s

      if compact
        "#{fragment_string} query get#{type}($id: ID!) { #{query_name_value}(id: $id) { ...#{fragment_name_value} } }"
      else
        "#{fragment_string}\n\nquery get#{type}($id: ID!) {\n  #{query_name_value}(id: $id) {\n    ...#{fragment_name_value}\n  }\n}\n"
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
        included_connections: @included_connections
      )
    end
  end
end
