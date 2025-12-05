# frozen_string_literal: true

RSpec.describe "GID handling in nested connections" do
  before do
    customer_class = Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type 'Customer'

      attribute :id
      attribute :email

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

    order_class = Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type 'Order'

      attribute :id
      attribute :created_at, type: :datetime

      def self.name
        'Order'
      end

      def self.model_name
        ActiveModel::Name.new(self, nil, 'Order')
      end

      def self.default_loader_class
        ActiveShopifyGraphQL::AdminApiLoader
      end
    end

    stub_const('Customer', customer_class)
    stub_const('Order', order_class)

    customer_class.class_eval do
      has_many_connected :orders, default_arguments: { first: 10 }
    end

    @customer_class = customer_class
    @order_class = order_class
  end

  describe "extract_gid_from_parent" do
    let(:loader) { ActiveShopifyGraphQL::AdminApiLoader.new(@order_class) }

    it "returns GID as-is when parent has full GID" do
      customer = @customer_class.new(id: 'gid://shopify/Customer/123')
      gid = loader.send(:extract_gid_from_parent, customer)

      expect(gid).to eq('gid://shopify/Customer/123')
    end

    it "reconstructs GID from numeric ID" do
      customer = @customer_class.new(id: '7285147926827')
      gid = loader.send(:extract_gid_from_parent, customer)

      expect(gid).to eq('gid://shopify/Customer/7285147926827')
    end

    it "uses gid attribute if available" do
      customer = @customer_class.new(id: '123')
      allow(customer).to receive(:gid).and_return('gid://shopify/Customer/999')

      gid = loader.send(:extract_gid_from_parent, customer)

      expect(gid).to eq('gid://shopify/Customer/999')
    end

    it "handles integer IDs" do
      customer = @customer_class.new(id: 7_285_147_926_827)
      gid = loader.send(:extract_gid_from_parent, customer)

      expect(gid).to eq('gid://shopify/Customer/7285147926827')
    end
  end

  describe "load_connection_records with numeric parent ID" do
    let(:mock_client) { double('GraphQLClient') }

    before do
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)
      allow(ActiveShopifyGraphQL.configuration).to receive(:log_queries).and_return(false)
    end

    it "passes reconstructed GID to GraphQL query" do
      # Create customer with numeric ID (simulating application that strips GIDs)
      customer = @customer_class.new(id: '7285147926827')

      # Expect the GraphQL client to receive a query with the full GID
      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:id]).to eq('gid://shopify/Customer/7285147926827')
        { "data" => { "customer" => { "orders" => { "edges" => [] } } } }
      end

      # Trigger the connection load
      loader = ActiveShopifyGraphQL::AdminApiLoader.new(@order_class)
      config = { nested: true, type: :connection, query_name: 'orders' }
      loader.load_connection_records('orders', { first: 10 }, customer, config)
    end

    it "passes existing GID unchanged to GraphQL query" do
      # Create customer with full GID
      customer = @customer_class.new(id: 'gid://shopify/Customer/7285147926827')

      # Expect the GraphQL client to receive the same GID
      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:id]).to eq('gid://shopify/Customer/7285147926827')
        { "data" => { "customer" => { "orders" => { "edges" => [] } } } }
      end

      # Trigger the connection load
      loader = ActiveShopifyGraphQL::AdminApiLoader.new(@order_class)
      config = { nested: true, type: :connection, query_name: 'orders' }
      loader.load_connection_records('orders', { first: 10 }, customer, config)
    end

    it "uses gid attribute if present" do
      # Create customer with numeric ID but gid attribute
      customer = @customer_class.new(id: '123')
      allow(customer).to receive(:gid).and_return('gid://shopify/Customer/7285147926827')

      # Expect the GraphQL client to receive the GID from gid attribute
      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:id]).to eq('gid://shopify/Customer/7285147926827')
        { "data" => { "customer" => { "orders" => { "edges" => [] } } } }
      end

      # Trigger the connection load
      loader = ActiveShopifyGraphQL::AdminApiLoader.new(@order_class)
      config = { nested: true, type: :connection, query_name: 'orders' }
      loader.load_connection_records('orders', { first: 10 }, customer, config)
    end
  end
end
