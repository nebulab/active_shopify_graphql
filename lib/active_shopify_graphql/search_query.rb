# frozen_string_literal: true

require_relative "search_query/hash_condition_formatter"
require_relative "search_query/parameter_binder"

module ActiveShopifyGraphQL
  # Represents a Shopify search query, converting Ruby conditions into Shopify's search syntax
  # Supports hash-based conditions (with sanitization), string-based conditions (raw), and parameter binding
  #
  # @example Hash-based query (safe, with sanitization)
  #   SearchQuery.new(sku: "ABC-123").to_s
  #   # => "sku:'ABC-123'"
  #
  # @example String-based query (raw, user responsibility for safety)
  #   SearchQuery.new("sku:* AND product_id:123").to_s
  #   # => "sku:* AND product_id:123"
  #
  # @example String with positional parameter binding
  #   SearchQuery.new("sku:? product_id:?", "Good ol' value", 123).to_s
  #   # => "sku:'Good ol\\' value' product_id:123"
  #
  # @example String with named parameter binding
  #   SearchQuery.new("sku::sku product_id::product_id", { sku: "A-SKU", product_id: 123 }).to_s
  #   # => "sku:'A-SKU' product_id:123"
  class SearchQuery
    def initialize(conditions = {}, *args)
      @conditions = conditions
      @args = args
    end

    # Converts conditions to Shopify search query string
    # @return [String] The Shopify query string
    def to_s
      case @conditions
      when Hash
        HashConditionFormatter.format(@conditions)
      when String
        if @args.empty?
          @conditions
        else
          ParameterBinder.bind(@conditions, *@args)
        end
      when Array
        # Handle [query_string, *binding_args] format from FinderMethods#where
        query_string = @conditions.first
        binding_args = @conditions[1..]
        ParameterBinder.bind(query_string, *binding_args)
      else
        ""
      end
    end
  end
end
