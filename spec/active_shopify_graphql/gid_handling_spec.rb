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
    it "returns GID as-is when parent has full GID" do
      loader = ActiveShopifyGraphQL::Loaders::AdminApiLoader.new(@order_class)
      context = loader.context
      connection_loader = ActiveShopifyGraphQL::ConnectionLoader.new(context, loader_instance: loader)

      customer = @customer_class.new(id: 'gid://shopify/Customer/123')
      gid = connection_loader.send(:extract_gid, customer)

      expect(gid).to eq('gid://shopify/Customer/123')
    end

    it "reconstructs GID from numeric ID" do
      loader = ActiveShopifyGraphQL::Loaders::AdminApiLoader.new(@order_class)
      context = loader.context
      connection_loader = ActiveShopifyGraphQL::ConnectionLoader.new(context, loader_instance: loader)

      customer = @customer_class.new(id: '7285147926827')
      gid = connection_loader.send(:extract_gid, customer)

      expect(gid).to eq('gid://shopify/Customer/7285147926827')
    end

    it "uses gid attribute if available" do
      loader = ActiveShopifyGraphQL::Loaders::AdminApiLoader.new(@order_class)
      context = loader.context
      connection_loader = ActiveShopifyGraphQL::ConnectionLoader.new(context, loader_instance: loader)

      customer = @customer_class.new(id: '123')
      allow(customer).to receive(:gid).and_return('gid://shopify/Customer/999')

      gid = connection_loader.send(:extract_gid, customer)

      expect(gid).to eq('gid://shopify/Customer/999')
    end

    it "handles integer IDs" do
      loader = ActiveShopifyGraphQL::Loaders::AdminApiLoader.new(@order_class)
      context = loader.context
      connection_loader = ActiveShopifyGraphQL::ConnectionLoader.new(context, loader_instance: loader)

      customer = @customer_class.new(id: 7_285_147_926_827)
      gid = connection_loader.send(:extract_gid, customer)

      expect(gid).to eq('gid://shopify/Customer/7285147926827')
    end
  end

  describe "load_connection_records with numeric parent ID" do
    it "passes reconstructed GID to GraphQL query" do
      mock_client = instance_double("GraphQLClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)
      allow(ActiveShopifyGraphQL.configuration).to receive(:log_queries).and_return(false)

      customer = @customer_class.new(id: '7285147926827')

      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:id]).to eq('gid://shopify/Customer/7285147926827')
        { "data" => { "customer" => { "orders" => { "edges" => [] } } } }
      end

      loader = ActiveShopifyGraphQL::Loaders::AdminApiLoader.new(@order_class)
      config = { nested: true, type: :connection, query_name: 'orders' }
      loader.load_connection_records('orders', { first: 10 }, customer, config)
    end

    it "passes existing GID unchanged to GraphQL query" do
      mock_client = instance_double("GraphQLClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)
      allow(ActiveShopifyGraphQL.configuration).to receive(:log_queries).and_return(false)

      customer = @customer_class.new(id: 'gid://shopify/Customer/7285147926827')

      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:id]).to eq('gid://shopify/Customer/7285147926827')
        { "data" => { "customer" => { "orders" => { "edges" => [] } } } }
      end

      loader = ActiveShopifyGraphQL::Loaders::AdminApiLoader.new(@order_class)
      config = { nested: true, type: :connection, query_name: 'orders' }
      loader.load_connection_records('orders', { first: 10 }, customer, config)
    end

    it "uses gid attribute if present" do
      mock_client = instance_double("GraphQLClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)
      allow(ActiveShopifyGraphQL.configuration).to receive(:log_queries).and_return(false)

      customer = @customer_class.new(id: '123')
      allow(customer).to receive(:gid).and_return('gid://shopify/Customer/7285147926827')

      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:id]).to eq('gid://shopify/Customer/7285147926827')
        { "data" => { "customer" => { "orders" => { "edges" => [] } } } }
      end

      loader = ActiveShopifyGraphQL::Loaders::AdminApiLoader.new(@order_class)
      config = { nested: true, type: :connection, query_name: 'orders' }
      loader.load_connection_records('orders', { first: 10 }, customer, config)
    end
  end

  describe "FinderMethods#find with GID handling" do
    it "accepts numeric ID and builds GID" do
      mock_client = instance_double("GraphQLClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)
      allow(ActiveShopifyGraphQL.configuration).to receive(:log_queries).and_return(false)

      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:id]).to eq('gid://shopify/Customer/123')
        { "data" => { "customer" => { "id" => "gid://shopify/Customer/123", "email" => "test@example.com" } } }
      end

      customer = @customer_class.find(123)
      expect(customer).not_to be_nil
      expect(customer.id).to eq("gid://shopify/Customer/123")
    end

    it "accepts string numeric ID and builds GID" do
      mock_client = instance_double("GraphQLClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)
      allow(ActiveShopifyGraphQL.configuration).to receive(:log_queries).and_return(false)

      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:id]).to eq('gid://shopify/Customer/456')
        { "data" => { "customer" => { "id" => "gid://shopify/Customer/456", "email" => "test@example.com" } } }
      end

      customer = @customer_class.find("456")
      expect(customer).not_to be_nil
      expect(customer.id).to eq("gid://shopify/Customer/456")
    end

    it "accepts existing GID and uses it as-is" do
      mock_client = instance_double("GraphQLClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)
      allow(ActiveShopifyGraphQL.configuration).to receive(:log_queries).and_return(false)

      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:id]).to eq('gid://shopify/Customer/789')
        { "data" => { "customer" => { "id" => "gid://shopify/Customer/789", "email" => "test@example.com" } } }
      end

      customer = @customer_class.find("gid://shopify/Customer/789")
      expect(customer).not_to be_nil
      expect(customer.id).to eq("gid://shopify/Customer/789")
    end

    it "handles invalid GID string by building new GID" do
      mock_client = instance_double("GraphQLClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)
      allow(ActiveShopifyGraphQL.configuration).to receive(:log_queries).and_return(false)

      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:id]).to eq('gid://shopify/Customer/not-a-gid')
        { "data" => { "customer" => { "id" => "gid://shopify/Customer/not-a-gid", "email" => "test@example.com" } } }
      end

      customer = @customer_class.find("not-a-gid")
      expect(customer).not_to be_nil
    end
  end

  describe "LoaderSwitchable with GID handling" do
    it "accepts numeric ID and builds GID" do
      mock_client = instance_double("GraphQLClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)
      allow(ActiveShopifyGraphQL.configuration).to receive(:log_queries).and_return(false)

      loader = ActiveShopifyGraphQL::Loaders::AdminApiLoader.new(@customer_class)
      proxy = ActiveShopifyGraphQL::LoaderSwitchable::LoaderProxy.new(@customer_class, loader)

      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:id]).to eq('gid://shopify/Customer/123')
        { "data" => { "customer" => { "id" => "gid://shopify/Customer/123", "email" => "test@example.com" } } }
      end

      customer = proxy.find(123)
      expect(customer).not_to be_nil
      expect(customer.id).to eq("gid://shopify/Customer/123")
    end

    it "accepts existing GID and uses it as-is" do
      mock_client = instance_double("GraphQLClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)
      allow(ActiveShopifyGraphQL.configuration).to receive(:log_queries).and_return(false)

      loader = ActiveShopifyGraphQL::Loaders::AdminApiLoader.new(@customer_class)
      proxy = ActiveShopifyGraphQL::LoaderSwitchable::LoaderProxy.new(@customer_class, loader)

      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:id]).to eq('gid://shopify/Customer/789')
        { "data" => { "customer" => { "id" => "gid://shopify/Customer/789", "email" => "test@example.com" } } }
      end

      customer = proxy.find("gid://shopify/Customer/789")
      expect(customer).not_to be_nil
      expect(customer.id).to eq("gid://shopify/Customer/789")
    end

    it "handles invalid GID string by building new GID" do
      mock_client = instance_double("GraphQLClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)
      allow(ActiveShopifyGraphQL.configuration).to receive(:log_queries).and_return(false)

      loader = ActiveShopifyGraphQL::Loaders::AdminApiLoader.new(@customer_class)
      proxy = ActiveShopifyGraphQL::LoaderSwitchable::LoaderProxy.new(@customer_class, loader)

      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:id]).to eq('gid://shopify/Customer/not-a-gid')
        { "data" => { "customer" => { "id" => "gid://shopify/Customer/not-a-gid", "email" => "test@example.com" } } }
      end

      customer = proxy.find("not-a-gid")
      expect(customer).not_to be_nil
    end
  end
end
