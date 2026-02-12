# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Adapters::ShopifyApiCustomerAccount do
  describe "#initialize" do
    it "requires an access_token parameter" do
      expect { described_class.new }.to raise_error(ArgumentError)
    end

    it "accepts an access_token parameter" do
      adapter = described_class.new(access_token: "customer_token_123")
      expect(adapter).to be_a(described_class)
    end
  end

  describe "#execute" do
    it "executes a query using ShopifyAPI customer account client" do
      response_body = { "data" => { "customer" => { "email" => "customer@example.com" } } }

      stub_client = Class.new do
        def initialize(access_token:); end

        define_method(:query) do |query:, variables:|
          obj = Object.new
          obj.define_singleton_method(:body) { response_body }
          obj
        end
      end

      stub_api = Module.new
      graphql_module = Module.new
      graphql_module.const_set(:CustomerAccount, stub_client)
      clients_module = Module.new
      clients_module.const_set(:Graphql, graphql_module)
      stub_api.const_set(:Clients, clients_module)

      stub_const("ShopifyAPI", stub_api)

      adapter = described_class.new(access_token: "customer_token_123")
      result = adapter.execute("query { customer { email } }")

      expect(result).to eq({ "customer" => { "email" => "customer@example.com" } })
    end

    it "passes variables to the ShopifyAPI client" do
      received_variables = nil
      response_body = nil

      stub_client = Class.new do
        def initialize(access_token:); end

        define_method(:query) do |query:, variables:|
          received_variables = variables
          response_body = { "data" => { "order" => { "id" => variables[:id], "status" => "OPEN" } } }
          obj = Object.new
          obj.define_singleton_method(:body) { response_body }
          obj
        end
      end

      stub_api = Module.new
      graphql_module = Module.new
      graphql_module.const_set(:CustomerAccount, stub_client)
      clients_module = Module.new
      clients_module.const_set(:Graphql, graphql_module)
      stub_api.const_set(:Clients, clients_module)

      stub_const("ShopifyAPI", stub_api)

      adapter = described_class.new(access_token: "customer_token_123")
      result = adapter.execute("query { order }", id: "gid://shopify/Order/456")

      expect(received_variables).to eq({ id: "gid://shopify/Order/456" })
      expect(result).to eq({ "order" => { "id" => "gid://shopify/Order/456", "status" => "OPEN" } })
    end

    it "raises an error when the response contains errors" do
      response_body = {
        "errors" => [
          { "message" => "Unauthorized access" }
        ]
      }

      stub_client = Class.new do
        def initialize(access_token:); end

        define_method(:query) do |query:, variables:|
          obj = Object.new
          obj.define_singleton_method(:body) { response_body }
          obj
        end
      end

      stub_api = Module.new
      graphql_module = Module.new
      graphql_module.const_set(:CustomerAccount, stub_client)
      clients_module = Module.new
      clients_module.const_set(:Graphql, graphql_module)
      stub_api.const_set(:Clients, clients_module)

      stub_const("ShopifyAPI", stub_api)

      adapter = described_class.new(access_token: "invalid_token")

      expect { adapter.execute("query { customer { email } }") }.to raise_error(
        StandardError,
        "GraphQL errors: Unauthorized access"
      )
    end

    it "uses the provided access token" do
      captured_token = nil

      stub_client = Class.new do
        define_method(:initialize) do |access_token:|
          captured_token = access_token
        end

        define_method(:query) do |query:, variables:|
          obj = Object.new
          obj.define_singleton_method(:body) { { "data" => {} } }
          obj
        end
      end

      stub_api = Module.new
      graphql_module = Module.new
      graphql_module.const_set(:CustomerAccount, stub_client)
      clients_module = Module.new
      clients_module.const_set(:Graphql, graphql_module)
      stub_api.const_set(:Clients, clients_module)

      stub_const("ShopifyAPI", stub_api)

      adapter = described_class.new(access_token: "customer_token_456")
      adapter.execute("query { customer { email } }")

      expect(captured_token).to eq("customer_token_456")
    end

    it "formats multiple error messages" do
      response_body = {
        "errors" => [
          { "message" => "First error" },
          { "message" => "Second error" },
          { "message" => "Third error" }
        ]
      }

      stub_client = Class.new do
        def initialize(access_token:); end

        define_method(:query) do |query:, variables:|
          obj = Object.new
          obj.define_singleton_method(:body) { response_body }
          obj
        end
      end

      stub_api = Module.new
      graphql_module = Module.new
      graphql_module.const_set(:CustomerAccount, stub_client)
      clients_module = Module.new
      clients_module.const_set(:Graphql, graphql_module)
      stub_api.const_set(:Clients, clients_module)

      stub_const("ShopifyAPI", stub_api)

      adapter = described_class.new(access_token: "token")

      expect { adapter.execute("query { customer { invalid } }") }.to raise_error(
        StandardError,
        "GraphQL errors: First error, Second error, Third error"
      )
    end
  end
end
