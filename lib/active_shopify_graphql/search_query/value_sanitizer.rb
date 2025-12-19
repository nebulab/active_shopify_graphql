# frozen_string_literal: true

module ActiveShopifyGraphQL
  class SearchQuery
    # Sanitizes values by escaping special characters for Shopify search syntax
    class ValueSanitizer
      # Sanitizes a value by escaping special characters
      # @param value [String] The value to sanitize
      # @return [String] The sanitized value
      def self.sanitize(value)
        value
          .gsub('\\', '\\\\\\\\') # Escape backslashes first: \ becomes \\
          .gsub('"', '\\"') # Escape double quotes with a single backslash
          # Escape single quotes: O'Reilly becomes O\\'Reilly
          # Why 4 backslashes? The escaping happens in layers:
          # 1. Ruby string literal: "\\\\\\\\''" = literal string "\\\\''"
          # 2. String interpolation in "#{key}:'#{escaped_value}'": the \\\' becomes \\'
          # 3. Final GraphQL query: customers(query: "title:'O\\'Reilly'")
          # The double backslash is required by Shopify's search syntax to properly escape the single quote
          .gsub("'", "\\\\\\\\'")
      end
    end
  end
end
