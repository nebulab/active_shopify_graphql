# frozen_string_literal: true

require "spec_helper"

RSpec.describe "SortKey parameter behavior" do
  # Create test model classes
  let(:order_class) do
    Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type 'Order'

      attribute :id
      connection :line_items, default_arguments: { first: 10 }

      def self.name
        'Order'
      end
    end
  end

  let(:line_item_class) do
    Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type 'LineItem'

      attribute :id
      attribute :quantity

      def self.name
        'LineItem'
      end
    end
  end

  let(:product_class) do
    Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type 'Product'

      attribute :id
      connection :variants, default_arguments: { first: 10 }

      def self.name
        'Product'
      end
    end
  end

  let(:product_variant_class) do
    Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type 'ProductVariant'

      attribute :id
      attribute :price

      def self.name
        'ProductVariant'
      end
    end
  end

  let(:order) { order_class.new(id: 1) }
  let(:product) { product_class.new(id: 1) }

  before do
    # Stub constants for the test classes
    stub_const('Order', order_class)
    stub_const('LineItem', line_item_class)
    stub_const('Product', product_class)
    stub_const('ProductVariant', product_variant_class)
  end

  describe "connection configuration" do
    it "stores correct metadata for nested connections" do
      connections = order_class.connections
      line_items_config = connections[:line_items]

      # Should have been automatically configured as nested
      expect(line_items_config).to include(
        class_name: 'LineItem',
        query_name: 'lineItems'
      )
    end

    it "stores correct metadata for root-level connections" do
      connections = product_class.connections
      variants_config = connections[:variants]

      # Should not have sort_key unless explicitly provided
      expect(variants_config[:sort_key]).to be_nil
    end
  end

  describe "connection proxy behavior" do
    it "creates connection proxies for nested connections" do
      # Create a connection proxy to trigger the nested query logic
      connection_proxy = order.line_items

      # The proxy should be created successfully
      expect(connection_proxy).to be_a(ActiveShopifyGraphQL::Connections::ConnectionProxy)
    end

    it "creates connection proxies for root-level connections" do
      # Create a connection proxy for root-level connection
      connection_proxy = product.variants

      # Should be a regular connection proxy
      expect(connection_proxy).to be_a(ActiveShopifyGraphQL::Connections::ConnectionProxy)
    end
  end
end
