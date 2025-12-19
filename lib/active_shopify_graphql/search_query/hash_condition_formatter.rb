# frozen_string_literal: true

require_relative "value_sanitizer"

module ActiveShopifyGraphQL
  class SearchQuery
    # Formats hash-based query conditions with proper sanitization
    class HashConditionFormatter
      # Formats hash conditions into a Shopify search query string
      # @param conditions [Hash] The conditions to format
      # @return [String] The formatted query string
      def self.format(conditions)
        return "" if conditions.empty?

        query_parts = conditions.map do |key, value|
          format_condition(key.to_s, value)
        end

        query_parts.join(" AND ")
      end

      # Formats a single query condition
      # @param key [String] The attribute name
      # @param value [Object] The attribute value
      # @return [String] The formatted query condition
      def self.format_condition(key, value)
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
      def self.format_array_condition(key, values)
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
      def self.format_single_value(key, value)
        case value
        when String
          format_string_condition(key, value)
        when Numeric, true, false
          "#{key}:#{value}"
        else
          "#{key}:#{value}"
        end
      end

      # Formats a string condition with proper quoting and sanitization
      # @param key [String] The attribute name
      # @param value [String] The string value
      # @return [String] The formatted condition
      def self.format_string_condition(key, value)
        escaped_value = ValueSanitizer.sanitize(value)
        "#{key}:'#{escaped_value}'"
      end

      # Formats a range condition (e.g., { created_at: { gte: '2024-01-01' } })
      # @param key [String] The attribute name
      # @param value [Hash] The range conditions
      # @return [String] The formatted range condition
      def self.format_range_condition(key, value)
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

      private_class_method :format_condition, :format_array_condition,
                           :format_single_value, :format_string_condition,
                           :format_range_condition
    end
  end
end
