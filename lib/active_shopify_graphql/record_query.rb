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
      fragment_string = fragment_to_s

      query_builder = Query.new
      query_builder.wrap_fragment_in_query(
        fragment_string: fragment_string,
        fragment_name: fragment_name_value,
        query_name: "#{query_name_value}(id: $id)",
        query_signature: "get#{type}($id: ID!)"
      )
    end

    private

    # Convert fragment to string, handling both Fragment objects and legacy string fragments
    def fragment_to_s
      @fragment.is_a?(String) ? @fragment : @fragment.to_s
    end

    # Extract fragment name from Fragment object or string
    def extract_fragment_name(type_name)
      if @fragment.is_a?(String)
        # Extract fragment name from string (legacy support)
        @fragment[/fragment\s+(\w+)/, 1] || "#{type_name}Fragment"
      elsif @fragment.respond_to?(:fragment_name)
        @fragment.fragment_name
      else
        "#{type_name}Fragment"
      end
    end
  end
end
