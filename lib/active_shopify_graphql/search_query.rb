# frozen_string_literal: true

require_relative "search_query/hash_condition_formatter"

module ActiveShopifyGraphQL
  # Represents a Shopify search query, converting Ruby conditions into Shopify's search syntax
  # Supports both hash-based conditions (with sanitization) and string-based conditions (raw)
  #
  # @example Hash-based query (safe, with sanitization)
  #   SearchQuery.new(sku: "ABC-123").to_s
  #   # => "sku:'ABC-123'"
  #
  # @example String-based query (raw, user responsibility for safety)
  #   SearchQuery.new("sku:* AND product_id:123").to_s
  #   # => "sku:* AND product_id:123"
  class SearchQuery
    def initialize(conditions = {})
      @conditions = conditions
    end

    # Converts conditions to Shopify search query string
    # @return [String] The Shopify query string
    def to_s
      case @conditions
      when Hash
        HashConditionFormatter.format(@conditions)
      when String
        @conditions
      else
        ""
      end
    end
  end
end
