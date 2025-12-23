# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ActiveShopifyGraphQL::LoaderProxy do
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
      allow(relation_loader).to receive(:perform_graphql_query).and_return({ "data" => { "customer" => { "id" => "gid://shopify/Customer/123", "orders" => { "nodes" => [] } } } })
      relation_loader.load_attributes

      expect(relation_loader).to have_received(:perform_graphql_query) do |query, **_vars|
        expect(query).to include("orders(")
        expect(query).to include("nodes {")
      end
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
      allow(mock_client).to receive(:execute).and_return({ "data" => { "customers" => { "nodes" => [] } } })
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
