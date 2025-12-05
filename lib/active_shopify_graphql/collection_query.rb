# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Handles collection querying with Shopify's search syntax
  class CollectionQuery
    attr_reader :graphql_type

    def initialize(graphql_type:, query_builder:, query_name_proc:, map_response_proc:, client_type:)
      @graphql_type = graphql_type
      @query_builder = query_builder
      @query_name_proc = query_name_proc
      @map_response_proc = map_response_proc
      @client_type = client_type
    end

    # Executes a collection query using Shopify's search syntax and returns an array of mapped attributes
    # @param conditions [Hash] The conditions to query
    # @param limit [Integer] The maximum number of records to return (default: 250, max: 250)
    # @return [Array<Hash>] Array of attribute hashes or empty array if none found
    def execute(conditions = {}, limit: 250)
      query_string = build_query_string(conditions)
      query = @query_builder.collection_graphql_query(@graphql_type)
      variables = { query: query_string, first: limit }

      executor = Executor.new(@client_type)
      response = executor.execute(query, **variables)

      # Check for search warnings/errors in extensions
      validate_search_response(response)

      # Map the response to attributes
      map_response(response, @graphql_type)
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

    # Builds a Shopify GraphQL query string from Ruby conditions
    # @param conditions [Hash] The query conditions
    # @return [String] The Shopify query string
    def build_query_string(conditions)
      return "" if conditions.empty?

      query_parts = conditions.map do |key, value|
        format_condition(key.to_s, value)
      end

      query_parts.join(" AND ")
    end

    # Formats a single query condition into Shopify's query syntax
    # @param key [String] The attribute name
    # @param value [Object] The attribute value
    # @return [String] The formatted query condition
    def format_condition(key, value)
      case value
      when String
        format_string_condition(key, value)
      when Numeric, true, false
        "#{key}:#{value}"
      when Hash
        format_range_condition(key, value)
      else
        "#{key}:#{value}"
      end
    end

    # Formats a string condition with proper quoting
    def format_string_condition(key, value)
      # Handle special string values and escape quotes
      if value.include?(" ") && !value.start_with?('"')
        # Multi-word values should be quoted
        "#{key}:\"#{value.gsub('"', '\\"')}\""
      else
        "#{key}:#{value}"
      end
    end

    # Formats a range condition (e.g., { created_at: { gte: '2024-01-01' } })
    def format_range_condition(key, value)
      range_parts = value.map do |operator, range_value|
        case operator.to_sym
        when :gt, :>
          "#{key}:>#{range_value}"
        when :gte, :>=
          "#{key}:>=#{range_value}"
        when :lt, :<
          "#{key}:<#{range_value}"
        when :lte, :<=
          "#{key}:<=#{range_value}"
        else
          raise ArgumentError, "Unsupported range operator: #{operator}"
        end
      end
      range_parts.join(" ")
    end
  end
end
