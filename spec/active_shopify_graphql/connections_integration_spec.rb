# frozen_string_literal: true

RSpec.describe 'ActiveShopifyGraphQL Connections Integration' do
  # Create example model classes to demonstrate the API
  let(:customer_class) do
    Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type 'Customer'

      attribute :id
      attribute :display_name, path: "displayName"
      attribute :email

      connection :orders, foreign_key: 'customer_id', default_arguments: { first: 10 }
      connection :addresses, foreign_key: 'customer_id', default_arguments: { first: 5 }

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

  it 'defines connections with proper metadata' do
    expect(Customer.connections).to have_key(:orders)
    expect(Customer.connections).to have_key(:addresses)

    orders_config = Customer.connections[:orders]
    expect(orders_config[:class_name]).to eq('Order')
    expect(orders_config[:query_name]).to eq('orders')
    expect(orders_config[:default_arguments][:first]).to eq(10)

    addresses_config = Customer.connections[:addresses]
    expect(addresses_config[:class_name]).to eq('Address')
    expect(addresses_config[:default_arguments][:first]).to eq(5)
  end

  it 'creates connection proxy objects' do
    customer = Customer.new(id: 'gid://shopify/Customer/123')

    orders_proxy = customer.orders
    expect(orders_proxy).to be_a(ActiveShopifyGraphQL::Connections::ConnectionProxy)
    expect(orders_proxy.loaded?).to be false

    addresses_proxy = customer.addresses
    expect(addresses_proxy).to be_a(ActiveShopifyGraphQL::Connections::ConnectionProxy)
    expect(addresses_proxy.loaded?).to be false
  end

  it 'supports eager loading with includes' do
    included_class = Customer.includes(:orders, :addresses)

    expect(included_class).not_to eq(Customer)
    expect(included_class.name).to eq('Customer')

    # Verify the includes configuration is preserved
    loader_instance_var = included_class.instance_variable_get(:@included_connections)
    expect(loader_instance_var).to eq(%i[orders addresses])
  end

  it 'supports method chaining' do
    # These should all work without errors
    expect { Customer.includes(:orders) }.not_to raise_error
    expect { Customer.includes(:orders).includes(:addresses) }.not_to raise_error
  end

  it 'validates connection names' do
    expect do
      Customer.includes(:invalid_connection)
    end.to raise_error(ArgumentError, /Invalid connection for Customer: invalid_connection/)
  end

  it 'allows runtime parameter overrides' do
    customer = Customer.new(id: 'gid://shopify/Customer/123')

    # This should create a proxy with custom parameters
    orders_proxy = customer.orders(first: 25, sort_key: 'UPDATED_AT', reverse: true)
    expect(orders_proxy).to be_a(ActiveShopifyGraphQL::Connections::ConnectionProxy)
  end

  it 'supports manual connection caching for testing' do
    customer = Customer.new(id: 'gid://shopify/Customer/123')
    mock_orders = [Order.new(id: 'gid://shopify/Order/1', name: '#1001')]

    customer.orders = mock_orders
    expect(customer.orders).to eq(mock_orders)
  end

  describe 'connection proxy enumerable interface' do
    it 'implements array-like methods' do
      customer = Customer.new(id: 'gid://shopify/Customer/123')
      mock_orders = [
        Order.new(id: 'gid://shopify/Order/1', name: '#1001'),
        Order.new(id: 'gid://shopify/Order/2', name: '#1002')
      ]

      customer.orders = mock_orders
      orders = customer.orders

      expect(orders.size).to eq(2)
      expect(orders.length).to eq(2)
      expect(orders.count).to eq(2)
      expect(orders.first).to eq(mock_orders.first)
      expect(orders.last).to eq(mock_orders.last)
      expect(orders[0]).to eq(mock_orders.first)
      expect(orders[1]).to eq(mock_orders.last)
      expect(orders.empty?).to be false
    end
  end
end
