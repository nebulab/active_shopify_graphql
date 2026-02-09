# frozen_string_literal: true

require_relative "testing/condition_matcher"
require_relative "testing/test_registry"
require_relative "testing/test_loader"
require_relative "testing/test_helpers"

module ActiveShopifyGraphQL
  # Testing module provides utilities for testing code that uses
  # ActiveShopifyGraphQL models without making real network requests.
  #
  # When enabled, all model queries read from an in-memory registry
  # instead of hitting the Shopify GraphQL API. This allows for fast,
  # deterministic tests with complete control over the data.
  #
  # @example Basic setup in spec_helper.rb
  #   require 'active_shopify_graphql/testing'
  #
  #   RSpec.configure do |config|
  #     config.include ActiveShopifyGraphQL::Testing::TestHelpers
  #
  #     config.before(:suite) do
  #       ActiveShopifyGraphQL::Testing.enable!
  #     end
  #
  #     config.after(:each) do
  #       clear_graphql_records!
  #     end
  #   end
  #
  # @example Using in a test
  #   describe "Customer lookup" do
  #     it "finds customer by ID" do
  #       create_graphql_record(Customer, id: 123, email: "test@example.com")
  #
  #       customer = Customer.find(123)
  #
  #       expect(customer.email).to eq("test@example.com")
  #     end
  #
  #     it "filters customers with where" do
  #       create_graphql_records(Customer, [
  #         { id: 1, status: "active", email: "a@test.com" },
  #         { id: 2, status: "inactive", email: "b@test.com" },
  #         { id: 3, status: "active", email: "c@test.com" }
  #       ])
  #
  #       active_customers = Customer.where(status: "active").to_a
  #
  #       expect(active_customers.map(&:email)).to contain_exactly("a@test.com", "c@test.com")
  #     end
  #   end
  module Testing
    class << self
      # Enable test mode globally
      # All model queries will read from the TestRegistry instead of the network
      #
      # @return [void]
      def enable!
        ActiveShopifyGraphQL.configuration.test_mode = true
      end

      # Disable test mode and restore normal operation
      #
      # @return [void]
      def disable!
        ActiveShopifyGraphQL.configuration.test_mode = false
        TestRegistry.clear!
        TestLoader.last_requested_loader_class = nil
      end

      # Check if test mode is currently enabled
      #
      # @return [Boolean]
      def enabled?
        ActiveShopifyGraphQL.configuration.test_mode?
      end

      # Execute a block with test mode enabled, then restore previous state
      #
      # @yield Block to execute with test mode enabled
      # @return [Object] Result of the block
      #
      # @example
      #   ActiveShopifyGraphQL::Testing.with_test_mode do
      #     create_graphql_record(Customer, id: 1)
      #     Customer.find(1)
      #   end
      def with_test_mode
        was_enabled = enabled?
        enable!
        yield
      ensure
        disable! unless was_enabled
      end
    end
  end
end
