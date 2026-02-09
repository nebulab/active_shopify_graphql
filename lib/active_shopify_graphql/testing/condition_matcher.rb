# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Testing
    # Evaluates hash-based conditions against record attributes.
    # Mirrors the operators supported by SearchQuery::HashConditionFormatter.
    #
    # Supports:
    # - Simple equality: { email: "test@example.com" }
    # - Array (OR): { status: ["active", "pending"] }
    # - Range operators: { amount: { gt: 100 } }, { created_at: { gte: "2024-01-01" } }
    #
    # @example Filtering records
    #   records = [{ email: "a@test.com" }, { email: "b@test.com" }]
    #   ConditionMatcher.filter(records, { email: "a@test.com" })
    #   # => [{ email: "a@test.com" }]
    class ConditionMatcher
      # Filter an array of records by conditions
      # @param records [Array<Hash>] The records to filter
      # @param conditions [Hash] The filter conditions
      # @return [Array<Hash>] Records matching all conditions
      def self.filter(records, conditions)
        return records if conditions.nil? || conditions.empty?

        records.select { |record| matches?(record, conditions) }
      end

      # Check if a single record matches all conditions
      # @param record [Hash] The record to check
      # @param conditions [Hash] The conditions to match against
      # @return [Boolean] true if record matches all conditions
      def self.matches?(record, conditions)
        conditions.all? do |key, expected|
          actual = record[key.to_sym] || record[key.to_s]
          match_value?(actual, expected)
        end
      end

      # Match a single value against an expected value/pattern
      # @param actual [Object] The actual record value
      # @param expected [Object] The expected value, array, or range hash
      # @return [Boolean] true if values match
      def self.match_value?(actual, expected)
        case expected
        when Array
          match_array?(actual, expected)
        when Hash
          match_range?(actual, expected)
        else
          match_equality?(actual, expected)
        end
      end

      # Match against array of values (OR semantics)
      # @param actual [Object] The actual record value
      # @param expected_values [Array] Possible matching values
      # @return [Boolean] true if actual matches any expected value
      def self.match_array?(actual, expected_values)
        expected_values.any? { |expected| match_equality?(actual, expected) }
      end

      # Match against range operators
      # @param actual [Object] The actual record value
      # @param range_conditions [Hash] Hash with operator keys (:gt, :gte, :lt, :lte)
      # @return [Boolean] true if all range conditions are satisfied
      def self.match_range?(actual, range_conditions)
        return false if actual.nil?

        range_conditions.all? do |operator, expected|
          compare_with_operator(actual, operator.to_sym, expected)
        end
      end

      # Compare values using an operator
      # @param actual [Object] The actual value
      # @param operator [Symbol] The comparison operator
      # @param expected [Object] The expected value
      # @return [Boolean] Comparison result
      def self.compare_with_operator(actual, operator, expected)
        # Convert to comparable types if possible
        actual_comparable = to_comparable(actual)
        expected_comparable = to_comparable(expected)

        case operator
        when :gt, :>
          actual_comparable > expected_comparable
        when :gte, :>=
          actual_comparable >= expected_comparable
        when :lt, :<
          actual_comparable < expected_comparable
        when :lte, :<=
          actual_comparable <= expected_comparable
        else
          raise ArgumentError, "Unsupported range operator: #{operator}"
        end
      rescue ArgumentError => e
        raise e if e.message.include?("Unsupported range operator")

        false # Comparison failed due to type mismatch
      end

      # Match equality between actual and expected values
      # @param actual [Object] The actual record value
      # @param expected [Object] The expected value
      # @return [Boolean] true if values are equal
      def self.match_equality?(actual, expected)
        # Handle nil
        return actual.nil? if expected.nil?
        return false if actual.nil?

        # Normalize to strings for comparison if types differ
        if actual.class == expected.class
          actual == expected
        else
          actual.to_s == expected.to_s
        end
      end

      # Convert value to a comparable type
      # @param value [Object] The value to convert
      # @return [Object] A comparable representation
      def self.to_comparable(value)
        case value
        when Numeric
          value
        when String
          # Try to parse as date/time first, then number
          if value.match?(/^\d{4}-\d{2}-\d{2}/)
            begin
              Time.parse(value)
            rescue StandardError
              value
            end
          elsif value.match?(/^-?\d+(\.\d+)?$/)
            value.include?('.') ? value.to_f : value.to_i
          else
            value
          end
        else
          value
        end
      end
    end
  end
end
