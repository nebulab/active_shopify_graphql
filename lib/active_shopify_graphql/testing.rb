# frozen_string_literal: true

require_relative "testing/store"
require_relative "testing/test_loader"
require_relative "testing/hook"

module ActiveShopifyGraphQL
  # Testing support module that provides an in-memory store for test data,
  # allowing developers to register records using Ruby-level attributes and
  # have find, where, includes, and connections work transparently without
  # real API calls.
  #
  # @example In spec_helper.rb
  #   require 'active_shopify_graphql/testing'
  #
  #   RSpec.configure do |config|
  #     config.before(:each) { ActiveShopifyGraphQL::Testing.enable! }
  #     config.after(:each)  { ActiveShopifyGraphQL::Testing.reset! }
  #   end
  #
  # @example In tests
  #   ActiveShopifyGraphQL::Testing.register(Customer, [
  #     { id: 1, email: "john@example.com", display_name: "John" }
  #   ])
  #   Customer.find(1) # => Customer instance from the store
  #
  module Testing
    class << self
      def enable!
        @enabled = true
      end

      def reset!
        @enabled = false
        store.clear
      end

      def enabled?
        @enabled == true
      end

      def store
        @store ||= Store.new
      end

      # Convenience delegate to store.register
      def register(model_class, records)
        store.register(model_class, records)
      end
    end
  end
end

# Apply hooks once at load time
ActiveShopifyGraphQL::Model::LoaderSwitchable::ClassMethods.prepend(
  ActiveShopifyGraphQL::Testing::LoaderSwitchableHook
)
ActiveShopifyGraphQL::Model::FinderMethods::ClassMethods.prepend(
  ActiveShopifyGraphQL::Testing::FinderMethodsHook
)
ActiveShopifyGraphQL::Model::Attributes::ClassMethods.prepend(
  ActiveShopifyGraphQL::Testing::AttributesHook
)
ActiveShopifyGraphQL::Model::GraphqlTypeResolver::ClassMethods.prepend(
  ActiveShopifyGraphQL::Testing::GraphqlTypeResolverHook
)
