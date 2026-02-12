# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Adapters::Base do
  describe "#execute" do
    it "raises NotImplementedError when called directly" do
      adapter = described_class.new

      expect { adapter.execute("query { shop { name } }") }.to raise_error(
        NotImplementedError,
        "ActiveShopifyGraphQL::Adapters::Base must implement #execute"
      )
    end

    it "raises NotImplementedError when called with variables" do
      adapter = described_class.new

      expect { adapter.execute("query($id: ID!) { node(id: $id) }", id: "123") }.to raise_error(
        NotImplementedError,
        "ActiveShopifyGraphQL::Adapters::Base must implement #execute"
      )
    end

    it "can be subclassed and implemented" do
      custom_adapter_class = Class.new(described_class) do
        def execute(_query, **_variables)
          { "data" => { "shop" => { "name" => "Test Shop" } } }
        end
      end

      adapter = custom_adapter_class.new
      result = adapter.execute("query { shop { name } }")

      expect(result).to eq({ "data" => { "shop" => { "name" => "Test Shop" } } })
    end

    it "passes variables through to subclass implementation" do
      custom_adapter_class = Class.new(described_class) do
        def execute(query, **variables)
          { "query" => query, "variables" => variables }
        end
      end

      adapter = custom_adapter_class.new
      result = adapter.execute("query($id: ID!) { node(id: $id) }", id: "gid://shopify/Product/123")

      expect(result).to eq({ "query" => "query($id: ID!) { node(id: $id) }",
                             "variables" => { id: "gid://shopify/Product/123" } })
    end
  end
end
