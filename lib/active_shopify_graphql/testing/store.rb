# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Testing
    # In-memory data store for test records.
    # Stores records keyed by model class, with IDs normalized to GID format.
    # Supports lookup by ID, filtering by hash/string conditions, and
    # extracting inline connection data from parent records.
    class Store
      def initialize
        @data = {}
      end

      # Register test records for a model class.
      # IDs are normalized to GID format using the model's graphql_type.
      #
      # @param model_class [Class] The model class (e.g., Customer)
      # @param records [Array<Hash>] Array of attribute hashes
      def register(model_class, records)
        graphql_type = model_class.graphql_type_for_loader(model_class.send(:default_loader_class))

        @data[model_class] = records.map do |record|
          record = record.dup
          record[:id] = GidHelper.normalize_gid(record[:id], graphql_type) if record.key?(:id)
          record
        end
      end

      # Find a single record by normalized GID.
      #
      # @param model_class [Class] The model class
      # @param id [String] The GID to look up
      # @return [Hash, nil] The matching record or nil
      def find(model_class, id)
        records = @data[model_class] || []
        records.find { |r| r[:id] == id }
      end

      # Filter records by conditions.
      # Hash conditions: match against ALL keys in stored hash (attributes + search fields).
      # String conditions: parse simple key:value patterns, fallback to return all.
      # Comparison uses .to_s on both sides so plain IDs match naturally.
      #
      # @param model_class [Class] The model class
      # @param conditions [Hash, String] The filter conditions
      # @return [Array<Hash>] Matching records
      def where(model_class, conditions)
        records = @data[model_class] || []

        case conditions
        when Hash
          filter_by_hash(records, normalize_conditions(model_class, conditions))
        when String
          filter_by_string(records, conditions)
        else
          records
        end
      end

      # Extract inline connection data from a parent's stored record.
      #
      # @param model_class [Class] The parent model class
      # @param id [String] The parent's GID
      # @param connection_name [Symbol] The connection key name
      # @return [Array<Hash>, Hash, nil] The connection data
      def connections_for(model_class, id, connection_name)
        record = find(model_class, id)
        return nil unless record

        record[connection_name]
      end

      # Clear all stored data.
      def clear
        @data.clear
      end

      private

      def filter_by_hash(records, conditions)
        records.select do |record|
          conditions.all? do |key, value|
            next false unless record.key?(key)

            case value
            when Array
              value.any? { |v| record[key].to_s == v.to_s }
            else
              record[key].to_s == value.to_s
            end
          end
        end
      end

      # Normalize :id values in conditions to GIDs so they match stored records.
      def normalize_conditions(model_class, conditions)
        return conditions unless conditions.key?(:id)

        graphql_type = model_class.graphql_type_for_loader(model_class.send(:default_loader_class))
        normalized = conditions.dup

        normalized[:id] =
          case conditions[:id]
          when Array
            conditions[:id].map { |v| GidHelper.normalize_gid(v, graphql_type) }
          else
            GidHelper.normalize_gid(conditions[:id], graphql_type)
          end

        normalized
      end

      def filter_by_string(records, query)
        return records if query.nil? || query.strip.empty?

        # Parse simple key:'value' or key:value patterns
        # Bail on wildcards or complex boolean queries
        return records if query.include?("*") || query.include?(" AND ") || query.include?(" OR ")

        pairs = parse_search_query(query)
        return records if pairs.empty?

        filter_by_hash(records, pairs)
      end

      # Parse a simple Shopify search query string into key-value pairs.
      # Handles: key:'value', key:"value", key:value
      def parse_search_query(query)
        pairs = {}
        # Match key:'value', key:"value", or key:unquoted_value
        query.scan(/(\w+):(?:'([^']*)'|"([^"]*)"|(\S+))/) do |key, sq, dq, uq|
          pairs[key.to_sym] = sq || dq || uq
        end
        pairs
      end
    end
  end
end
