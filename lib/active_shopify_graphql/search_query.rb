# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Represents a Shopify search query, converting Ruby conditions into Shopify's search syntax
  class SearchQuery
    def initialize(conditions = {})
      @conditions = conditions
    end

    # Converts conditions to Shopify search query string
    # @return [String] The Shopify query string
    def to_s
      return "" if @conditions.empty?

      query_parts = @conditions.map do |key, value|
        format_condition(key.to_s, value)
      end

      query_parts.join(" AND ")
    end

    private

    # Formats a single query condition into Shopify's query syntax
    # @param key [String] The attribute name
    # @param value [Object] The attribute value
    # @return [String] The formatted query condition
    def format_condition(key, value)
      case value
      when Array
        format_array_condition(key, value)
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

    # Formats an array condition with OR clauses
    # @param key [String] The attribute name
    # @param values [Array] The array of values
    # @return [String] The formatted query with OR clauses wrapped in parentheses
    def format_array_condition(key, values)
      return "" if values.empty?
      return format_condition(key, values.first) if values.size == 1

      or_parts = values.map do |value|
        format_single_value(key, value)
      end

      "(#{or_parts.join(' OR ')})"
    end

    # Formats a single value for use in array OR clauses
    # @param key [String] The attribute name
    # @param value [Object] The attribute value
    # @return [String] The formatted key:value pair
    def format_single_value(key, value)
      case value
      when String
        format_string_condition(key, value)
      when Numeric, true, false
        "#{key}:#{value}"
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
