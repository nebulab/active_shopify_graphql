# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Adapters::ShopifyApiAdmin do
  describe "#execute" do
    it "executes a query using ShopifyAPI admin client" do
      response_body = { "data" => { "shop" => { "name" => "Test Shop" } } }

      stub_context = Class.new do
        def self.active_session
          "session_123"
        end
      end

      stub_client = Class.new do
        def initialize(session:); end

        define_method(:query) do |query:, variables:|
          obj = Object.new
          obj.define_singleton_method(:body) { response_body }
          obj
        end
      end

      stub_api = Module.new
      stub_api.const_set(:Context, stub_context)
      graphql_module = Module.new
      graphql_module.const_set(:Admin, stub_client)
      clients_module = Module.new
      clients_module.const_set(:Graphql, graphql_module)
      stub_api.const_set(:Clients, clients_module)

      stub_const("ShopifyAPI", stub_api)

      adapter = described_class.new
      result = adapter.execute("query { shop { name } }")

      expect(result).to eq({ "shop" => { "name" => "Test Shop" } })
    end

    it "passes variables to the ShopifyAPI client" do
      received_variables = nil
      response_body = nil

      stub_context = Class.new do
        def self.active_session
          "session_123"
        end
      end

      stub_client = Class.new do
        def initialize(session:); end

        define_method(:query) do |query:, variables:|
          received_variables = variables
          response_body = { "data" => { "product" => { "id" => variables[:id] } } }
          obj = Object.new
          obj.define_singleton_method(:body) { response_body }
          obj
        end
      end

      stub_api = Module.new
      stub_api.const_set(:Context, stub_context)
      graphql_module = Module.new
      graphql_module.const_set(:Admin, stub_client)
      clients_module = Module.new
      clients_module.const_set(:Graphql, graphql_module)
      stub_api.const_set(:Clients, clients_module)

      stub_const("ShopifyAPI", stub_api)

      adapter = described_class.new
      result = adapter.execute("query { product }", id: "gid://shopify/Product/123")

      expect(received_variables).to eq({ id: "gid://shopify/Product/123" })
      expect(result).to eq({ "product" => { "id" => "gid://shopify/Product/123" } })
    end

    it "raises an error when the response contains errors" do
      response_body = {
        "errors" => [
          { "message" => "Field 'invalid' doesn't exist on type 'Shop'" },
          { "message" => "Another error occurred" }
        ]
      }

      stub_context = Class.new do
        def self.active_session
          "session_123"
        end
      end

      stub_client = Class.new do
        def initialize(session:); end

        define_method(:query) do |query:, variables:|
          obj = Object.new
          obj.define_singleton_method(:body) { response_body }
          obj
        end
      end

      stub_api = Module.new
      stub_api.const_set(:Context, stub_context)
      graphql_module = Module.new
      graphql_module.const_set(:Admin, stub_client)
      clients_module = Module.new
      clients_module.const_set(:Graphql, graphql_module)
      stub_api.const_set(:Clients, clients_module)

      stub_const("ShopifyAPI", stub_api)

      adapter = described_class.new

      expect { adapter.execute("query { shop { invalid } }") }.to raise_error(
        StandardError,
        "GraphQL errors: Field 'invalid' doesn't exist on type 'Shop', Another error occurred"
      )
    end

    it "uses the active session from ShopifyAPI::Context" do
      session_token = "my_session_token"
      captured_session = nil

      stub_context = Class.new do
        class << self
          attr_accessor :token

          def active_session
            token
          end
        end
      end
      stub_context.token = session_token

      stub_client = Class.new do
        define_method(:initialize) do |session:|
          captured_session = session
        end

        define_method(:query) do |query:, variables:|
          obj = Object.new
          obj.define_singleton_method(:body) { { "data" => {} } }
          obj
        end
      end

      stub_api = Module.new
      stub_api.const_set(:Context, stub_context)
      graphql_module = Module.new
      graphql_module.const_set(:Admin, stub_client)
      clients_module = Module.new
      clients_module.const_set(:Graphql, graphql_module)
      stub_api.const_set(:Clients, clients_module)

      stub_const("ShopifyAPI", stub_api)

      adapter = described_class.new
      adapter.execute("query { shop { name } }")

      expect(captured_session).to eq(session_token)
    end
  end
end
