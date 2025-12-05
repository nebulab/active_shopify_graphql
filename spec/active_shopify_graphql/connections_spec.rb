# frozen_string_literal: true

RSpec.describe ActiveShopifyGraphQL::Connections do
  # Create test model classes
  let(:customer_class) do
    Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type 'Customer'

      attribute :id
      attribute :tags
      attribute :name, path: "displayName"

      connection :orders, foreign_key: 'customer_id', default_arguments: { first: 10, sort_key: 'CREATED_AT', reverse: false }
      connection :addresses, class_name: 'Address', query_name: 'customerAddresses', foreign_key: 'customer_id', default_arguments: { first: 5, sort_key: 'CREATED_AT', reverse: false }

      def self.name
        'Customer'
      end

      def self.model_name
        ActiveModel::Name.new(self, nil, 'Customer')
      end

      def self.default_loader_class
        ActiveShopifyGraphQL::AdminApiLoader
      end
    end
  end

  let(:order_class) do
    Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type 'Order'

      attribute :id
      attribute :name
      attribute :total_price, path: "totalPriceSet.shopMoney.amount"

      def self.name
        'Order'
      end

      def self.model_name
        ActiveModel::Name.new(self, nil, 'Order')
      end
    end
  end

  let(:address_class) do
    Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type 'MailingAddress'

      attribute :id
      attribute :address1
      attribute :city

      def self.name
        'Address'
      end

      def self.model_name
        ActiveModel::Name.new(self, nil, 'Address')
      end
    end
  end

  before do
    stub_const('Customer', customer_class)
    stub_const('Order', order_class)
    stub_const('Address', address_class)
  end

  describe '.connection' do
    it 'defines connection metadata' do
      connections = customer_class.connections

      expect(connections).to have_key(:orders)

      expect(connections[:orders]).to include(
        class_name: 'Order',
        query_name: 'orders',
        foreign_key: 'customer_id',
        loader_class: nil
      )
      expect(connections[:orders][:default_arguments]).to include(
        first: 10,
        sort_key: 'CREATED_AT',
        reverse: false
      )
    end

    it 'allows customization of connection parameters' do
      connections = customer_class.connections

      expect(connections[:addresses]).to include(
        class_name: 'Address',
        query_name: 'customerAddresses',
        foreign_key: 'customer_id'
      )
      expect(connections[:addresses][:default_arguments]).to include(
        first: 5,
        sort_key: 'CREATED_AT',
        reverse: false
      )
    end

    it 'defines connection accessor method' do
      customer = customer_class.new(id: 'gid://shopify/Customer/1')

      expect(customer).to respond_to(:orders)
      expect(customer).to respond_to(:addresses)
    end

    it 'defines connection setter method for testing' do
      customer = customer_class.new(id: 'gid://shopify/Customer/1')

      expect(customer).to respond_to(:orders=)
      expect(customer).to respond_to(:addresses=)
    end
  end

  describe 'connection proxy' do
    let(:customer) { customer_class.new(id: 'gid://shopify/Customer/1') }
    let(:mock_loader) { double('MockLoader') }

    before do
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(mock_loader).to receive(:class).and_return(ActiveShopifyGraphQL::AdminApiLoader)
      allow(ActiveShopifyGraphQL::AdminApiLoader).to receive(:new).and_return(mock_loader)

      # Allow the load_connection_records method to be called
      allow(mock_loader).to receive(:load_connection_records).and_return([])
    end

    it 'returns a ConnectionProxy when accessing connection' do
      proxy = customer.orders

      expect(proxy).to be_a(ActiveShopifyGraphQL::Connections::ConnectionProxy)
      expect(proxy.loaded?).to be false
    end

    it 'loads records when proxy is accessed' do
      mock_orders = [
        order_class.new(id: 'gid://shopify/Order/1', name: '#1001'),
        order_class.new(id: 'gid://shopify/Order/2', name: '#1002')
      ]

      expect(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = customer.orders
      orders = proxy.to_a

      expect(orders).to eq(mock_orders)
      expect(proxy.loaded?).to be true
    end

    it 'allows overriding connection parameters at runtime' do
      expect(mock_loader).to receive(:load_connection_records).and_return([])

      customer.orders(first: 20, sort_key: 'UPDATED_AT', reverse: true).to_a
    end

    it 'implements Enumerable methods' do
      mock_orders = [
        order_class.new(id: 'gid://shopify/Order/1', name: '#1001'),
        order_class.new(id: 'gid://shopify/Order/2', name: '#1002')
      ]

      expect(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = customer.orders

      expect(proxy.size).to eq(2)
      expect(proxy.first).to eq(mock_orders.first)
      expect(proxy.last).to eq(mock_orders.last)
      expect(proxy[0]).to eq(mock_orders.first)
      expect(proxy.empty?).to be false
    end

    it 'supports reloading' do
      expect(mock_loader).to receive(:load_connection_records).and_return([])

      proxy = customer.orders
      proxy.to_a # Load once
      expect(proxy.loaded?).to be true

      proxy.reload
      expect(proxy.loaded?).to be false
    end
  end

  describe '.includes' do
    let(:mock_loader_class) { ActiveShopifyGraphQL::AdminApiLoader }
    let(:mock_loader_instance) { double('MockLoader') }

    before do
      allow(customer_class).to receive(:default_loader).and_return(mock_loader_instance)
      allow(mock_loader_instance).to receive(:class).and_return(mock_loader_class)
      allow(mock_loader_class).to receive(:new).and_return(mock_loader_instance)
    end

    it 'validates connection names' do
      expect do
        customer_class.includes(:invalid_connection)
      end.to raise_error(ArgumentError, /Invalid connection for Customer: invalid_connection/)
    end

    it 'returns a modified class for method chaining' do
      included_class = customer_class.includes(:orders)

      expect(included_class).not_to eq(customer_class)
      expect(included_class.name).to eq('Customer')
      expect(included_class.model_name.name).to eq('Customer')
    end

    it 'creates loader with included connections' do
      expect(mock_loader_class).to receive(:new).with(
        customer_class,
        included_connections: %i[orders addresses]
      )

      customer_class.includes(:orders, :addresses).default_loader
    end

    it 'works with method chaining' do
      # This should not raise an error
      chained_class = customer_class.includes(:orders)

      expect(chained_class).to respond_to(:find)
      expect(chained_class).to respond_to(:where)
      expect(chained_class).to respond_to(:includes)
    end
  end

  describe 'eager loading' do
    let(:customer) { customer_class.new(id: 'gid://shopify/Customer/1') }

    it 'uses cached connection data when available' do
      mock_orders = [
        order_class.new(id: 'gid://shopify/Order/1', name: '#1001'),
        order_class.new(id: 'gid://shopify/Order/2', name: '#1002')
      ]

      # Simulate eager loaded data
      customer.instance_variable_set(:@_connection_cache, { orders: mock_orders })

      orders = customer.orders

      expect(orders).to eq(mock_orders)
      # Should not create a proxy since data is already loaded
      expect(orders).not_to be_a(ActiveShopifyGraphQL::Connections::ConnectionProxy)
    end

    it 'supports manual caching via setter' do
      mock_orders = [order_class.new(id: 'gid://shopify/Order/1', name: '#1001')]

      customer.orders = mock_orders

      expect(customer.orders).to eq(mock_orders)
    end
  end
end
