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

    it "accepts included_connections parameter" do
      model_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "Customer" }
        define_singleton_method(:attributes_for_loader) { |_| { id: { path: "id", type: :string } } }
        define_singleton_method(:connections) { {} }
      end

      loader = described_class.new(model_class, "test_token", included_connections: [:orders])

      expect(loader.instance_variable_get(:@included_connections)).to eq([:orders])
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

  describe "#graphql_query" do
    it "uses QueryTree.build_current_customer_query for Customer type" do
      model_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "Customer" }
        define_singleton_method(:attributes_for_loader) { |_| { id: { path: "id", type: :string } } }
        define_singleton_method(:connections) { {} }
      end
      loader = described_class.new(model_class, "fake_token")

      query = loader.graphql_query

      expect(query).to include("query getCurrentCustomer")
      expect(query).not_to include("$id")
      expect(query).to include("customer {")
    end

    it "includes connection fields when included_connections is set" do
      order_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "Order" }
        define_singleton_method(:attributes_for_loader) do |_|
          {
            id: { path: "id", type: :string },
            name: { path: "name", type: :string }
          }
        end
        define_singleton_method(:connections) { {} }
      end
      stub_const("Order", order_class)
      model_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "Customer" }
        define_singleton_method(:attributes_for_loader) do |_|
          {
            id: { path: "id", type: :string },
            email: { path: "email", type: :string }
          }
        end
        define_singleton_method(:connections) do
          {
            orders: {
              class_name: "Order",
              query_name: "orders",
              type: :connection,
              default_arguments: { first: 10, sort_key: "CREATED_AT" }
            }
          }
        end
      end
      loader = described_class.new(model_class, "fake_token", included_connections: [:orders])

      query = loader.graphql_query

      expect(query).to include("query getCurrentCustomer")
      expect(query).to include("orders(")
      expect(query).to include("edges {")
      expect(query).to include("node {")
    end

    it "uses QueryTree.build_single_record_query for non-Customer types" do
      model_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "Order" }
        define_singleton_method(:attributes_for_loader) { |_| { id: { path: "id", type: :string } } }
        define_singleton_method(:connections) { {} }
      end
      loader = described_class.new(model_class, "fake_token")

      query = loader.graphql_query

      expect(query).to include("query getOrder($id: ID!)")
      expect(query).to include("order(id: $id)")
    end
  end
end

RSpec.describe ActiveShopifyGraphQL::LoaderSwitchable::LoaderProxy do
  describe "#includes" do
    it "returns a new LoaderProxy with included_connections set" do
      order_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "Order" }
        define_singleton_method(:attributes_for_loader) do |_|
          { id: { path: "id", type: :string }, name: { path: "name", type: :string } }
        end
        define_singleton_method(:connections) { {} }
      end
      stub_const("Order", order_class)
      model_class = Class.new do
        include ActiveShopifyGraphQL::Base

        define_singleton_method(:graphql_type_for_loader) { |_| "Customer" }
        define_singleton_method(:attributes_for_loader) do |_|
          { id: { path: "id", type: :string }, email: { path: "email", type: :string } }
        end
        define_singleton_method(:connections) do
          {
            orders: {
              class_name: "Order",
              query_name: "orders",
              type: :connection,
              default_arguments: { first: 10 }
            }
          }
        end
        define_singleton_method(:model_name) { OpenStruct.new(name: "Customer") }
      end
      loader = ActiveShopifyGraphQL::Loaders::CustomerAccountApiLoader.new(model_class, "test_token")
      proxy = described_class.new(model_class, loader)

      new_proxy = proxy.includes(:orders)

      expect(new_proxy).to be_a(described_class)
      expect(new_proxy).not_to eq(proxy)
      expect(new_proxy.loader.instance_variable_get(:@included_connections)).to eq([:orders])
    end

    it "preserves token when creating new loader for CustomerAccountApiLoader" do
      model_class = Class.new do
        include ActiveShopifyGraphQL::Base

        define_singleton_method(:graphql_type_for_loader) { |_| "Customer" }
        define_singleton_method(:attributes_for_loader) do |_|
          { id: { path: "id", type: :string } }
        end
        define_singleton_method(:connections) { {} }
        define_singleton_method(:model_name) { OpenStruct.new(name: "Customer") }
      end
      loader = ActiveShopifyGraphQL::Loaders::CustomerAccountApiLoader.new(model_class, "my_secret_token")
      proxy = described_class.new(model_class, loader)

      new_proxy = proxy.includes

      expect(new_proxy.loader.instance_variable_get(:@token)).to eq("my_secret_token")
    end

    it "generates query with connection fields when includes is called" do
      order_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "Order" }
        define_singleton_method(:attributes_for_loader) do |_|
          { id: { path: "id", type: :string }, name: { path: "name", type: :string } }
        end
        define_singleton_method(:connections) { {} }
      end
      stub_const("Order", order_class)
      model_class = Class.new do
        include ActiveShopifyGraphQL::Base

        define_singleton_method(:graphql_type_for_loader) { |_| "Customer" }
        define_singleton_method(:attributes_for_loader) do |_|
          { id: { path: "id", type: :string }, email: { path: "email", type: :string } }
        end
        define_singleton_method(:connections) do
          {
            orders: {
              class_name: "Order",
              query_name: "orders",
              type: :connection,
              default_arguments: { first: 10 }
            }
          }
        end
        define_singleton_method(:model_name) { OpenStruct.new(name: "Customer") }
      end
      loader = ActiveShopifyGraphQL::Loaders::CustomerAccountApiLoader.new(model_class, "test_token")
      proxy = described_class.new(model_class, loader)

      new_proxy = proxy.includes(:orders)
      query = new_proxy.loader.graphql_query

      expect(query).to include("orders(")
      expect(query).to include("edges {")
      expect(query).to include("node {")
    end
  end

  describe "#select" do
    it "returns a new LoaderProxy with selected_attributes set" do
      model_class = Class.new do
        include ActiveShopifyGraphQL::Base

        define_singleton_method(:graphql_type_for_loader) { |_| "Customer" }
        define_singleton_method(:attributes_for_loader) do |_|
          { id: { path: "id", type: :string }, email: { path: "email", type: :string } }
        end
        define_singleton_method(:connections) { {} }
        define_singleton_method(:model_name) { OpenStruct.new(name: "Customer") }
      end
      loader = ActiveShopifyGraphQL::Loaders::CustomerAccountApiLoader.new(model_class, "test_token")
      proxy = described_class.new(model_class, loader)

      new_proxy = proxy.select(:id, :email)

      expect(new_proxy).to be_a(described_class)
      expect(new_proxy).not_to eq(proxy)
      expect(new_proxy.loader.instance_variable_get(:@selected_attributes)).to eq(%i[id email])
    end
  end
end
