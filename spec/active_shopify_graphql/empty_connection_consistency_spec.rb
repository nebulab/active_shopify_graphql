# frozen_string_literal: true

RSpec.describe "Empty connection consistency" do
  let(:customer_class) do
    Class.new do
      include ActiveShopifyGraphQL::Base
      graphql_type "Customer"
      attribute :id

      def self.name
        'Customer'
      end

      def self.model_name
        ActiveModel::Name.new(self, nil, 'Customer')
      end
    end
  end

  let(:order_class) do
    Class.new do
      include ActiveShopifyGraphQL::Base
      graphql_type "Order"
      attribute :id
      attribute :name

      def self.name
        'Order'
      end

      def self.model_name
        ActiveModel::Name.new(self, nil, 'Order')
      end
    end
  end

  before do
    stub_const('Customer', customer_class)
    stub_const('Order', order_class)

    customer_class.class_eval do
      has_many_connected :orders, default_arguments: { first: 10 }
    end
  end

  describe "has_many_connected returns empty array instead of nil" do
    let(:customer) { customer_class.new(id: 'gid://shopify/Customer/123') }
    let(:mock_loader) { double('MockLoader') }

    before do
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(mock_loader).to receive(:class).and_return(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
    end

    it "returns empty array when load_connection_records returns nil" do
      # Mock the loader to return nil (simulating an edge case)
      allow(mock_loader).to receive(:load_connection_records).and_return(nil)

      orders_proxy = customer.orders
      orders = orders_proxy.to_a

      # Verify we get an empty array, not nil
      expect(orders).to eq([])
      expect(orders).to be_a(Array)
    end

    it "returns empty array when load_connection_records returns empty array" do
      # Mock the loader to return empty array (normal case)
      allow(mock_loader).to receive(:load_connection_records).and_return([])

      orders_proxy = customer.orders
      orders = orders_proxy.to_a

      # Verify we get an empty array
      expect(orders).to eq([])
      expect(orders).to be_a(Array)
    end

    it "returns array with records when load_connection_records returns records" do
      mock_orders = [
        order_class.new(id: 'gid://shopify/Order/1', name: '#1001'),
        order_class.new(id: 'gid://shopify/Order/2', name: '#1002')
      ]

      # Mock the loader to return records
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      orders_proxy = customer.orders
      orders = orders_proxy.to_a

      # Verify we get the records
      expect(orders).to eq(mock_orders)
      expect(orders).to be_a(Array)
      expect(orders.size).to eq(2)
    end

    it "supports Enumerable methods on empty connection" do
      # Mock the loader to return nil
      allow(mock_loader).to receive(:load_connection_records).and_return(nil)

      orders_proxy = customer.orders

      # Verify Enumerable methods work correctly with empty connection
      expect(orders_proxy.empty?).to be true
      expect(orders_proxy.size).to eq(0)
      expect(orders_proxy.count).to eq(0)
      expect(orders_proxy.first).to be_nil
      expect(orders_proxy.last).to be_nil
      expect(orders_proxy.map(&:id)).to eq([])
    end
  end
end
