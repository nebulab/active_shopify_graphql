# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Handles collection querying with Shopify's search syntax
  class CollectionQuery
    attr_reader :graphql_type

    def initialize(graphql_type:, query_builder:, query_name_proc:, fragment_name_proc:, fragment_generator:, map_response_proc:, client_type:)
      @graphql_type = graphql_type
      @query_builder = query_builder
      @query_name_proc = query_name_proc
      @fragment_name_proc = fragment_name_proc
      @fragment_generator = fragment_generator
      @map_response_proc = map_response_proc
      @client_type = client_type
    end

    # Executes a collection query using Shopify's search syntax and returns an array of mapped attributes
    # @param conditions [Hash] The conditions to query
    # @param limit [Integer] The maximum number of records to return (default: 250, max: 250)
    # @return [Array<Hash>] Array of attribute hashes or empty array if none found
    def execute(conditions = {}, limit: 250)
      search_query = SearchQuery.new(conditions)
      query = collection_graphql_query(@graphql_type)
      variables = { query: search_query.to_s, first: limit }

      executor = Executor.new(@client_type)
      response = executor.execute(query, **variables)

      # Check for search warnings/errors in extensions
      validate_search_response(response)

      # Map the response to attributes
      map_response(response, @graphql_type)
    end

    # Builds the GraphQL query for collections
    # @param model_type [String] The model type (optional, uses class graphql_type if not provided)
    # @return [String] The GraphQL query string
    def collection_graphql_query(model_type = nil)
      type = model_type || @graphql_type
      query_name_value = @query_name_proc.call(type).pluralize
      fragment_name_value = @fragment_name_proc.call(type)

      if ActiveShopifyGraphQL.configuration.compact_queries
        "#{@fragment_generator.call} query get#{type.pluralize}($query: String, $first: Int!) { #{query_name_value}(query: $query, first: $first) { nodes { ...#{fragment_name_value} } } }"
      else
        <<~GRAPHQL
          #{@fragment_generator.call}
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

    # Validates the search response for warnings or errors
    def validate_search_response(response)
      return unless response.dig("extensions", "search")

      warnings = response["extensions"]["search"].flat_map { |search| search["warnings"] || [] }
      return if warnings.empty?

      warning_messages = warnings.map { |w| "#{w['field']}: #{w['message']}" }
      raise ArgumentError, "Shopify query validation failed: #{warning_messages.join(', ')}"
    end

    # Maps the collection response to an array of attribute hashes
    def map_response(response_data, type)
      query_name_value = @query_name_proc.call(type).pluralize
      nodes = response_data.dig("data", query_name_value, "nodes")

      return [] unless nodes&.any?

      nodes.map do |node_data|
        # Create a response structure similar to single record queries
        single_response = { "data" => { @query_name_proc.call(type) => node_data } }
        @map_response_proc.call(single_response)
      end.compact
    end
  end
end
