# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Testing
    # Mixin module providing helper methods for creating and managing
    # test records in the TestRegistry.
    #
    # Include this module in your test framework to get convenient methods
    # for setting up GraphQL record fixtures.
    #
    # @example RSpec setup
    #   RSpec.configure do |config|
    #     config.include ActiveShopifyGraphQL::Testing::TestHelpers
    #
    #     config.before(:each) do
    #       clear_graphql_records!
    #     end
    #   end
    #
    # @example Creating test records
    #   customer = create_graphql_record(Customer, id: 123, email: "test@example.com")
    #   found = Customer.find(123)
    #   expect(found.email).to eq("test@example.com")
    module TestHelpers
      # Create a single record in the test registry
      #
      # @param model_class [Class] The model class (e.g., Customer, Order)
      # @param attributes [Hash] The record attributes
      # @return [Hash] The registered record with normalized GID
      #
      # @example
      #   create_graphql_record(Customer, id: 123, email: "test@example.com")
      #   create_graphql_record(Customer, id: "gid://shopify/Customer/456", name: "John")
      def create_graphql_record(model_class, attributes = {})
        TestRegistry.register(model_class, attributes)
      end

      # Create multiple records in the test registry
      #
      # @param model_class [Class] The model class
      # @param attributes_array [Array<Hash>] Array of attribute hashes
      # @return [Array<Hash>] The registered records
      #
      # @example
      #   create_graphql_records(Customer, [
      #     { id: 1, email: "a@test.com" },
      #     { id: 2, email: "b@test.com" }
      #   ])
      def create_graphql_records(model_class, attributes_array)
        TestRegistry.register_many(model_class, attributes_array)
      end

      # Clear all records from the test registry
      # Call this in your test setup/teardown to ensure clean state
      #
      # @return [void]
      def clear_graphql_records!
        TestRegistry.clear!
      end

      # Get the loader class that was last requested
      # Useful for asserting that the correct loader was selected
      #
      # @return [Class, nil] The last requested loader class
      #
      # @example
      #   Customer.with_customer_account_api(token).find(123)
      #   expect(requested_loader_class).to eq(CustomerAccountApiLoader)
      def requested_loader_class
        TestLoader.last_requested_loader_class
      end

      # Check if any records exist in the registry
      #
      # @return [Boolean]
      def graphql_registry_empty?
        TestRegistry.empty?
      end

      # Count total records in the registry
      #
      # @return [Integer]
      def graphql_registry_count
        TestRegistry.count
      end
    end
  end
end
