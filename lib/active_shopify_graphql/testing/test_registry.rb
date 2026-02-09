# frozen_string_literal: true

require 'global_id'

module ActiveShopifyGraphQL
  module Testing
    # Thread-safe registry for storing test records that can be queried
    # during tests instead of hitting the network.
    #
    # Records are stored keyed by GraphQL type and GID, allowing efficient
    # lookup for find operations and attribute-based filtering for where queries.
    #
    # @example Registering a record
    #   TestRegistry.register(Customer, id: "gid://shopify/Customer/123", email: "test@example.com")
    #
    # @example Finding by GID
    #   TestRegistry.find_by_gid("gid://shopify/Customer/123")
    #   # => { id: "gid://shopify/Customer/123", email: "test@example.com", _model_class: Customer }
    #
    # @example Filtering records
    #   TestRegistry.filter(Customer, { email: "test@example.com" })
    #   # => [{ id: "...", email: "test@example.com", ... }]
    class TestRegistry
      class << self
        # Register a record in the test registry
        # @param model_class [Class] The model class (e.g., Customer, Order)
        # @param attributes [Hash] The record attributes including :id
        # @return [Hash] The registered record with normalized GID
        def register(model_class, attributes)
          attrs = attributes.transform_keys(&:to_sym)
          gid = normalize_gid(attrs[:id], model_class)
          attrs[:id] = gid

          record = attrs.merge(_model_class: model_class, _gid: gid)

          mutex.synchronize do
            records_by_gid[gid] = record
            records_by_type[graphql_type_for(model_class)] ||= []
            records_by_type[graphql_type_for(model_class)] << record
          end

          record
        end

        # Register multiple records at once
        # @param model_class [Class] The model class
        # @param attributes_array [Array<Hash>] Array of attribute hashes
        # @return [Array<Hash>] The registered records
        def register_many(model_class, attributes_array)
          attributes_array.map { |attrs| register(model_class, attrs) }
        end

        # Find a record by its GID
        # @param gid [String] The GraphQL Global ID
        # @return [Hash, nil] The record or nil if not found
        def find_by_gid(gid)
          mutex.synchronize { records_by_gid[gid]&.dup }
        end

        # Find all records for a given model class
        # @param model_class [Class] The model class
        # @return [Array<Hash>] All records for the model
        def find_all(model_class)
          graphql_type = graphql_type_for(model_class)
          mutex.synchronize do
            (records_by_type[graphql_type] || []).map(&:dup)
          end
        end

        # Filter records by hash conditions
        # @param model_class [Class] The model class
        # @param conditions [Hash] The filter conditions
        # @return [Array<Hash>] Matching records
        def filter(model_class, conditions)
          all_records = find_all(model_class)
          return all_records if conditions.nil? || conditions.empty?

          ConditionMatcher.filter(all_records, conditions)
        end

        # Clear all records from the registry
        # @return [void]
        def clear!
          mutex.synchronize do
            @records_by_gid = {}
            @records_by_type = {}
          end
        end

        # Check if the registry has any records
        # @return [Boolean]
        def empty?
          mutex.synchronize { records_by_gid.empty? }
        end

        # Count total records in the registry
        # @return [Integer]
        def count
          mutex.synchronize { records_by_gid.size }
        end

        private

        def mutex
          @mutex ||= Mutex.new
        end

        def records_by_gid
          @records_by_gid ||= {}
        end

        def records_by_type
          @records_by_type ||= {}
        end

        def normalize_gid(id, model_class)
          graphql_type = graphql_type_for(model_class)
          GidHelper.normalize_gid(id, graphql_type)
        end

        def graphql_type_for(model_class)
          if model_class.respond_to?(:graphql_type)
            model_class.graphql_type
          else
            model_class.name.demodulize
          end
        end
      end
    end
  end
end
