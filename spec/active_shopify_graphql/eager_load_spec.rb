# frozen_string_literal: true

RSpec.describe 'Connection eager_load parameter' do
  let(:customer_class) do
    Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type 'Customer'

      attribute :id
      attribute :display_name, path: "displayName"

      # Connection with eager_load: true should be automatically included
      connection :orders, foreign_key: 'customer_id', default_arguments: { first: 10 }, eager_load: true

      # Connection with eager_load: false (default) should be lazy loaded
      connection :addresses, foreign_key: 'customer_id', default_arguments: { first: 5 }, eager_load: false

      # Connection without eager_load specified (should default to false)
      connection :reviews, foreign_key: 'customer_id', default_arguments: { first: 20 }

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

  let(:address_class) do
    Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type 'MailingAddress'

      attribute :id
      attribute :address1

      def self.name
        'Address'
      end

      def self.model_name
        ActiveModel::Name.new(self, nil, 'Address')
      end
    end
  end

  let(:review_class) do
    Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type 'ProductReview'

      attribute :id
      attribute :rating

      def self.name
        'Review'
      end

      def self.model_name
        ActiveModel::Name.new(self, nil, 'Review')
      end
    end
  end

  before do
    stub_const('Customer', customer_class)
    stub_const('Order', order_class)
    stub_const('Address', address_class)
    stub_const('Review', review_class)
  end

  describe 'connection metadata' do
    it 'stores eager_load parameter in connection metadata' do
      connections = Customer.connections

      expect(connections[:orders][:eager_load]).to be true
      expect(connections[:addresses][:eager_load]).to be false
      expect(connections[:reviews][:eager_load]).to be false
    end
  end

  describe 'default_loader with automatic eager loading' do
    it 'automatically includes connections with eager_load: true' do
      default_loader = Customer.default_loader

      # Check if the loader was created with included_connections parameter
      # We can verify this by checking if the loader has the included connections
      expect(default_loader.instance_variable_get(:@included_connections)).to eq([:orders])
    end

    it 'does not include connections with eager_load: false or unspecified' do
      default_loader = Customer.default_loader

      included_connections = default_loader.instance_variable_get(:@included_connections)
      expect(included_connections).not_to include(:addresses)
      expect(included_connections).not_to include(:reviews)
    end
  end

  describe 'integration with find method' do
    it 'automatically eager loads connections with eager_load: true when using find' do
      # Mock the API client
      mock_client = instance_double("GraphQLClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)

      # Mock response that includes eager loaded orders connection
      mock_response = {
        "data" => {
          "customer" => {
            "id" => "gid://shopify/Customer/123",
            "displayName" => "John Doe",
            "orders" => {
              "edges" => [
                {
                  "node" => {
                    "id" => "gid://shopify/Order/1",
                    "name" => "#1001"
                  }
                }
              ]
            }
          }
        }
      }

      # Expect the client to be called with a query that includes the orders connection
      expect(mock_client).to receive(:execute) do |query, **variables|
        expect(query).to include("orders(first: 10")
        expect(query).to include("edges")
        expect(query).to include("node")
        expect(variables[:id].to_s).to eq("gid://shopify/Customer/123")
        mock_response
      end

      customer = Customer.find(123)

      # The orders connection should be cached (eager loaded)
      expect(customer.instance_variable_get(:@_connection_cache)).to include(:orders)
      expect(customer.orders).to be_an(Array)
      expect(customer.orders.size).to eq(1)
      expect(customer.orders.first.name).to eq("#1001")
    end
  end

  describe 'integration with where method' do
    it 'automatically eager loads connections with eager_load: true when using where' do
      # Mock the API client
      mock_client = instance_double("GraphQLClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)

      # Mock response for collection query with eager loaded orders
      mock_response = {
        "data" => {
          "customers" => {
            "nodes" => [
              {
                "id" => "gid://shopify/Customer/123",
                "displayName" => "John Doe",
                "orders" => {
                  "edges" => [
                    {
                      "node" => {
                        "id" => "gid://shopify/Order/1",
                        "name" => "#1001"
                      }
                    }
                  ]
                }
              }
            ]
          }
        }
      }

      # Expect the client to be called with a collection query that includes orders
      expect(mock_client).to receive(:execute) do |query, **variables|
        expect(query).to include("customers(query: $query")
        expect(query).to include("orders(first: 10")
        expect(variables[:query]).to eq("email:john@example.com")
        mock_response
      end

      customers = Customer.where(email: "john@example.com")

      expect(customers.size).to eq(1)
      customer = customers.first

      # The orders connection should be cached (eager loaded)
      expect(customer.instance_variable_get(:@_connection_cache)).to include(:orders)
      expect(customer.orders).to be_an(Array)
      expect(customer.orders.size).to eq(1)
      expect(customer.orders.first.name).to eq("#1001")
    end
  end

  describe 'behavior with includes method' do
    it 'allows manual includes in addition to automatic eager loading' do
      # When using includes, both manual and automatic connections should be loaded
      included_class = Customer.includes(:addresses)

      loader = included_class.default_loader
      included_connections = loader.instance_variable_get(:@included_connections)

      # Should include both the manually specified :addresses and the automatic :orders
      expect(included_connections).to include(:orders) # automatic eager_load
      expect(included_connections).to include(:addresses) # manual includes
    end

    it 'does not duplicate connections when manually including an auto-eager-loaded connection' do
      # If we manually include a connection that's already auto-eager-loaded, it shouldn't be duplicated
      included_class = Customer.includes(:orders)

      loader = included_class.default_loader
      included_connections = loader.instance_variable_get(:@included_connections)

      expect(included_connections.count(:orders)).to eq(1)
    end
  end

  describe 'lazy loading behavior for non-eager connections' do
    it 'lazy loads connections without eager_load: true' do
      customer = Customer.new(id: 'gid://shopify/Customer/123')

      # Mock loader for lazy connection
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(Customer).to receive(:default_loader).and_return(mock_loader)
      allow(mock_loader).to receive(:class).and_return(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)

      # The addresses connection should return a proxy (lazy loaded)
      addresses_proxy = customer.addresses
      expect(addresses_proxy).to be_a(ActiveShopifyGraphQL::Connections::ConnectionProxy)
      expect(addresses_proxy.loaded?).to be false
    end
  end
end
