# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Loaders::AdminApiLoader do
  describe "#perform_graphql_query" do
    it "executes query using configured admin_api_client" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      model_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "Customer" }
        define_singleton_method(:attributes_for_loader) { |_| { id: { path: "id", type: :string } } }
        define_singleton_method(:connections) { {} }
      end
      loader = described_class.new(model_class)
      expected_response = { "data" => { "customer" => { "id" => "123" } } }
      expect(mock_client).to receive(:execute).with("query { customer }").and_return(expected_response)

      result = loader.perform_graphql_query("query { customer }")

      expect(result).to eq(expected_response)
    end

    it "passes variables to client execute" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      model_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "Customer" }
        define_singleton_method(:attributes_for_loader) { |_| { id: { path: "id", type: :string } } }
        define_singleton_method(:connections) { {} }
      end
      loader = described_class.new(model_class)
      expect(mock_client).to receive(:execute).with("query { customer(id: $id) }", id: "123").and_return({})

      loader.perform_graphql_query("query { customer(id: $id) }", id: "123")
    end
  end

  describe ".client_type" do
    it "returns :admin_api" do
      expect(described_class.client_type).to eq(:admin_api)
    end
  end
end

RSpec.describe ActiveShopifyGraphQL::Loaders::CustomerAccountApiLoader do
  describe "#initialize" do
    it "accepts model class and token" do
      model_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "Customer" }
        define_singleton_method(:attributes_for_loader) { |_| { id: { path: "id", type: :string } } }
        define_singleton_method(:connections) { {} }
      end

      loader = described_class.new(model_class, "test_token")

      expect(loader.graphql_type).to eq("Customer")
    end
  end

  describe "#graphql_type" do
    it "gets graphql_type from model class" do
      model_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "Customer" }
        define_singleton_method(:attributes_for_loader) { |_| { id: { path: "id", type: :string } } }
        define_singleton_method(:connections) { {} }
      end

      loader = described_class.new(model_class, "fake_token")

      expect(loader.graphql_type).to eq("Customer")
    end
  end

  describe ".client_type" do
    it "returns :customer_account_api" do
      expect(described_class.client_type).to eq(:customer_account_api)
    end
  end
end
