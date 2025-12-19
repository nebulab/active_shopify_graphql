# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Loaders::AdminApiLoader do
  describe "#perform_graphql_query" do
    it "executes query using configured admin_api_client" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      model_class = build_customer_class
      loader = described_class.new(model_class)
      expected_response = { "data" => { "customer" => { "id" => "123" } } }
      expect(mock_client).to receive(:execute).with("query { customer }").and_return(expected_response)

      result = loader.perform_graphql_query("query { customer }")

      expect(result).to eq(expected_response)
    end

    it "passes variables to client execute" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      model_class = build_customer_class
      loader = described_class.new(model_class)
      expect(mock_client).to receive(:execute).with("query { customer(id: $id) }", id: "123").and_return({})

      loader.perform_graphql_query("query { customer(id: $id) }", id: "123")
    end
  end
end

RSpec.describe ActiveShopifyGraphQL::Loaders::CustomerAccountApiLoader do
  describe "#initialize" do
    it "accepts model class and token" do
      model_class = build_customer_class

      loader = described_class.new(model_class, "test_token")

      expect(loader.graphql_type).to eq("Customer")
    end

    it "accepts included_connections parameter" do
      model_class = build_customer_class

      loader = described_class.new(model_class, "test_token", included_connections: [:orders])

      expect(loader.instance_variable_get(:@included_connections)).to eq([:orders])
    end
  end

  describe "#graphql_type" do
    it "gets graphql_type from model class" do
      model_class = build_customer_class

      loader = described_class.new(model_class, "fake_token")

      expect(loader.graphql_type).to eq("Customer")
    end
  end

  describe "#graphql_query" do
    it "uses Query::Tree.build_current_customer_query for Customer type" do
      model_class = build_customer_class
      loader = described_class.new(model_class, "fake_token")

      query = loader.graphql_query

      expect(query).to include("query getCurrentCustomer")
      expect(query).not_to include("$id")
      expect(query).to include("customer {")
    end

    it "includes connection fields when included_connections is set" do
      order_class = build_order_class
      stub_const("Order", order_class)
      model_class = build_customer_class(with_orders: true)
      loader = described_class.new(model_class, "fake_token", included_connections: [:orders])

      query = loader.graphql_query

      expect(query).to include("query getCurrentCustomer")
      expect(query).to include("orders(")
      expect(query).to include("nodes {")
    end

    it "uses Query::Tree.build_single_record_query for non-Customer types" do
      model_class = build_order_class
      loader = described_class.new(model_class, "fake_token")

      query = loader.graphql_query

      expect(query).to include("query getOrder($id: ID!)")
      expect(query).to include("order(id: $id)")
    end
  end
end

RSpec.describe ActiveShopifyGraphQL::Model::LoaderSwitchable::LoaderProxy do
  describe "#includes" do
    it "returns a Relation with included_connections set" do
      order_class = build_order_class
      stub_const("Order", order_class)
      model_class = build_customer_class(with_orders: true)
      stub_const("Customer", model_class)
      loader = ActiveShopifyGraphQL::Loaders::CustomerAccountApiLoader.new(model_class, "test_token")
      proxy = described_class.new(model_class, loader)

      result = proxy.includes(:orders)

      expect(result).to be_a(ActiveShopifyGraphQL::Query::Relation)
      expect(result.included_connections).to include(:orders)
    end

    it "preserves loader class when creating Relation" do
      model_class = build_customer_class
      stub_const("Customer", model_class)
      loader = ActiveShopifyGraphQL::Loaders::CustomerAccountApiLoader.new(model_class, "my_secret_token")
      proxy = described_class.new(model_class, loader)

      result = proxy.all

      expect(result).to be_a(ActiveShopifyGraphQL::Query::Relation)
    end

    it "generates query with connection fields when includes is called" do
      order_class = build_order_class
      stub_const("Order", order_class)
      model_class = build_customer_class(with_orders: true)
      stub_const("Customer", model_class)
      loader = ActiveShopifyGraphQL::Loaders::CustomerAccountApiLoader.new(model_class, "test_token")
      proxy = described_class.new(model_class, loader)

      result = proxy.includes(:orders)
      relation_loader = result.send(:loader)
      query = relation_loader.graphql_query

      expect(query).to include("orders(")
      expect(query).to include("nodes {")
    end
  end

  describe "#select" do
    it "returns a Relation with selected_attributes set" do
      model_class = build_customer_class
      stub_const("Customer", model_class)
      loader = ActiveShopifyGraphQL::Loaders::CustomerAccountApiLoader.new(model_class, "test_token")
      proxy = described_class.new(model_class, loader)

      result = proxy.select(:id, :email)

      expect(result).to be_a(ActiveShopifyGraphQL::Query::Relation)
      relation_loader = result.send(:loader)
      expect(relation_loader.instance_variable_get(:@selected_attributes)).to eq(%i[id email])
    end
  end

  describe "#find_by" do
    it "delegates to Relation and returns first matching result" do
      model_class = build_customer_class
      stub_const("Customer", model_class)
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      allow(mock_client).to receive(:execute).and_return({ "data" => { "customers" => { "edges" => [] } } })
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }

      loader = ActiveShopifyGraphQL::Loaders::AdminApiLoader.new(model_class)
      proxy = described_class.new(model_class, loader)

      result = proxy.find_by(email: "test@example.com")

      expect(result).to be_nil
    end
  end

  describe "#where" do
    it "returns a Relation with conditions" do
      model_class = build_customer_class
      stub_const("Customer", model_class)
      loader = ActiveShopifyGraphQL::Loaders::AdminApiLoader.new(model_class)
      proxy = described_class.new(model_class, loader)

      result = proxy.where(email: "test@example.com")

      expect(result).to be_a(ActiveShopifyGraphQL::Query::Relation)
      expect(result.conditions).to eq(email: "test@example.com")
    end
  end
end
