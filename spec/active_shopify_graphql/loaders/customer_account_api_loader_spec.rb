# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Loaders::CustomerAccountApiLoader do
  describe "#initialize" do
    it "accepts model class and token" do
      model_class = build_customer_class

      loader = described_class.new(model_class, "test_token")

      expect(loader.context.graphql_type).to eq("Customer")
    end

    it "accepts included_connections parameter" do
      model_class = build_customer_class

      loader = described_class.new(model_class, "test_token", included_connections: [:orders])

      expect(loader.instance_variable_get(:@included_connections)).to eq([:orders])
    end
  end

  describe "#context" do
    it "gets graphql_type from model class" do
      model_class = build_customer_class

      loader = described_class.new(model_class, "fake_token")

      expect(loader.context.graphql_type).to eq("Customer")
    end
  end

  describe "#perform_graphql_query" do
    it "executes query using configured customer_account_api_executor" do
      expected_response = { "data" => { "customer" => { "id" => "123" } } }
      mock_executor = ->(query, token, **_variables) { expected_response if query == "query { customer }" && token == "test_token" }
      ActiveShopifyGraphQL.configure { |c| c.customer_account_api_executor = mock_executor }
      model_class = build_customer_class
      loader = described_class.new(model_class, "test_token")

      result = loader.perform_graphql_query("query { customer }")

      expect(result).to eq(expected_response)
    end

    it "passes token and variables to executor" do
      received_query = nil
      received_token = nil
      received_variables = nil
      mock_executor = lambda { |query, token, **variables|
        received_query = query
        received_token = token
        received_variables = variables
        {}
      }
      ActiveShopifyGraphQL.configure { |c| c.customer_account_api_executor = mock_executor }
      model_class = build_customer_class
      loader = described_class.new(model_class, "my_customer_token")

      loader.perform_graphql_query("query { customer(id: $id) }", id: "123")

      expect(received_query).to eq("query { customer(id: $id) }")
      expect(received_token).to eq("my_customer_token")
      expect(received_variables).to eq({ id: "123" })
    end

    it "raises error when customer_account_api_executor is nil" do
      ActiveShopifyGraphQL.configure { |c| c.customer_account_api_executor = nil }
      model_class = build_customer_class
      loader = described_class.new(model_class, "test_token")

      expect { loader.perform_graphql_query("query { customer }") }
        .to raise_error(ActiveShopifyGraphQL::Error, /Customer Account API executor not configured/)
    end
  end

  describe "#load_attributes" do
    it "builds current customer query for Customer type" do
      mock_executor = ->(_query, _token, **_variables) { { "data" => { "customer" => { "id" => "gid://shopify/Customer/123" } } } }
      ActiveShopifyGraphQL.configure { |c| c.customer_account_api_executor = mock_executor }
      model_class = build_customer_class
      loader = described_class.new(model_class, "fake_token")
      allow(loader).to receive(:perform_graphql_query).and_call_original

      loader.load_attributes

      expect(loader).to have_received(:perform_graphql_query) do |query, **_vars|
        expect(query).to include("query getCurrentCustomer")
        expect(query).not_to include("$id")
        expect(query).to include("customer {")
      end
    end

    it "includes connection fields when included_connections is set" do
      mock_executor = ->(_query, _token, **_variables) { { "data" => { "customer" => { "id" => "gid://shopify/Customer/123", "orders" => { "nodes" => [] } } } } }
      ActiveShopifyGraphQL.configure { |c| c.customer_account_api_executor = mock_executor }
      order_class = build_order_class
      stub_const("Order", order_class)
      model_class = build_customer_class(with_orders: true)
      loader = described_class.new(model_class, "fake_token", included_connections: [:orders])
      allow(loader).to receive(:perform_graphql_query).and_call_original

      loader.load_attributes

      expect(loader).to have_received(:perform_graphql_query) do |query, **_vars|
        expect(query).to include("query getCurrentCustomer")
        expect(query).to include("orders(")
        expect(query).to include("nodes {")
      end
    end

    it "builds single record query for non-Customer types" do
      mock_executor = ->(_query, _token, **_variables) { { "data" => { "order" => { "id" => "gid://shopify/Order/123" } } } }
      ActiveShopifyGraphQL.configure { |c| c.customer_account_api_executor = mock_executor }
      model_class = build_order_class
      loader = described_class.new(model_class, "fake_token")
      allow(loader).to receive(:perform_graphql_query).and_call_original

      loader.load_attributes("gid://shopify/Order/123")

      expect(loader).to have_received(:perform_graphql_query) do |query, **_vars|
        expect(query).to include("query getOrder($id: ID!)")
        expect(query).to include("order(id: $id)")
      end
    end
  end
end
