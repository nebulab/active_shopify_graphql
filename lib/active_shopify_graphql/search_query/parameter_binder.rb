# frozen_string_literal: true

require_relative "value_sanitizer"

module ActiveShopifyGraphQL
  class SearchQuery
    # Binds parameters to string queries with proper sanitization
    # Supports both positional (?) and named (:param) placeholders
    class ParameterBinder
      # Binds parameters to a query string
      # @param query_string [String] The query with placeholders
      # @param args [Array] Positional arguments or a hash of named parameters
      # @return [String] The query with bound and escaped parameters
      def self.bind(query_string, *args)
        return query_string if args.empty?

        if args.first.is_a?(Hash)
          bind_named_parameters(query_string, args.first)
        else
          bind_positional_parameters(query_string, args)
        end
      end

      # Binds positional parameters (?)
      # @param query_string [String] The query with ? placeholders
      # @param values [Array] The values to bind
      # @return [String] The query with bound parameters
      def self.bind_positional_parameters(query_string, values)
        result = query_string.dup
        values.each do |value|
          result = result.sub("?", format_value(value))
        end
        result
      end

      # Binds named parameters (:name)
      # @param query_string [String] The query with :name placeholders
      # @param params [Hash] The parameters hash
      # @return [String] The query with bound parameters
      def self.bind_named_parameters(query_string, params)
        result = query_string.dup
        params.each do |key, value|
          placeholder = ":#{key}"
          result = result.gsub(placeholder, format_value(value))
        end
        result
      end

      # Formats a value for safe insertion into query
      # @param value [Object] The value to format
      # @return [String] The formatted value
      def self.format_value(value)
        case value
        when String
          "'#{ValueSanitizer.sanitize(value)}'"
        when Numeric, true, false
          value.to_s
        when nil
          "null"
        else
          "'#{ValueSanitizer.sanitize(value.to_s)}'"
        end
      end

      private_class_method :bind_positional_parameters, :bind_named_parameters, :format_value
    end
  end
end
