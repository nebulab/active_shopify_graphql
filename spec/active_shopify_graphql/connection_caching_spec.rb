# frozen_string_literal: true

RSpec.describe 'Connection caching behavior' do
  let(:customer_class) do
    Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type 'Customer'

      attribute :id
      attribute :display_name, path: "displayName"

      connection :orders, foreign_key: 'customer_id', default_arguments: { first: 10 }

      def self.name
        'Customer'
      end

      def self.model_name
        ActiveModel::Name.new(self, nil, 'Customer')
      end

      def self.default_loader_class
        ActiveShopifyGraphQL::Loaders::AdminApiLoader
      end
    end
  end

  let(:order_class) do
    Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type 'Order'

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
  end

  it 'reuses the same connection proxy and does not re-evaluate queries' do
    customer = Customer.new(id: 'gid://shopify/Customer/123')

    # Mock the loader to track how many times load_connection_records is called
    mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
    allow(customer_class).to receive(:default_loader).and_return(mock_loader)
    allow(mock_loader).to receive(:class).and_return(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
    allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)

    mock_orders = [Order.new(id: 'gid://shopify/Order/1', name: '#1001')]

    # Expect load_connection_records to be called exactly once
    expect(mock_loader).to receive(:load_connection_records).once.and_return(mock_orders)

    # First access - should trigger the query
    orders_proxy1 = customer.orders
    expect(orders_proxy1.loaded?).to be false

    # Access .first to trigger loading
    first_order = customer.orders.first
    expect(first_order.name).to eq('#1001')

    # Second access to the same connection - should NOT trigger another query
    orders_proxy2 = customer.orders
    second_first_order = orders_proxy2.first
    expect(second_first_order.name).to eq('#1001')

    # The connection should be marked as loaded after first access
    expect(orders_proxy2.loaded?).to be true

    # Third access - still should not trigger another query
    orders_proxy3 = customer.orders
    third_first_order = orders_proxy3.first
    expect(third_first_order.name).to eq('#1001')
  end

  it 'creates new proxy instances with different options' do
    customer = Customer.new(id: 'gid://shopify/Customer/123')

    mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
    allow(customer_class).to receive(:default_loader).and_return(mock_loader)
    allow(mock_loader).to receive(:class).and_return(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
    allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)

    # Different options should create different queries
    expect(mock_loader).to receive(:load_connection_records).twice.and_return([])

    # First call with default options
    customer.orders.to_a

    # Second call with different options should create a new query
    customer.orders(first: 20).to_a
  end
end
