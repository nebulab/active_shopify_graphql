# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Adapters::Proc do
  describe "#initialize" do
    it "accepts a lambda in the constructor" do
      callable = ->(_query, **_variables) { { "data" => { "result" => "success" } } }
      adapter = described_class.new(callable)

      result = adapter.execute("query { test }")

      expect(result).to eq({ "data" => { "result" => "success" } })
    end

    it "accepts a proc in the constructor" do
      callable = proc { { "data" => { "result" => "success" } } }
      adapter = described_class.new(callable)

      result = adapter.execute("query { test }")

      expect(result).to eq({ "data" => { "result" => "success" } })
    end

    it "accepts a block instead of a callable argument" do
      adapter = described_class.new { { "data" => { "result" => "success" } } }

      result = adapter.execute("query { test }")

      expect(result).to eq({ "data" => { "result" => "success" } })
    end

    it "raises ArgumentError when neither callable nor block is provided" do
      expect { described_class.new }.to raise_error(ArgumentError, "Must provide a callable or block")
    end

    it "raises ArgumentError when provided object does not respond to call" do
      expect { described_class.new("not a callable") }.to raise_error(ArgumentError, "Must provide a callable or block")
    end
  end

  describe "#execute" do
    it "passes the query to the callable" do
      received_query = nil
      callable = lambda { |query, **_variables|
        received_query = query
        { "data" => {} }
      }
      adapter = described_class.new(callable)

      adapter.execute("query { shop { name } }")

      expect(received_query).to eq("query { shop { name } }")
    end

    it "passes variables to the callable" do
      received_variables = nil
      callable = lambda { |_query, **variables|
        received_variables = variables
        { "data" => { "product" => { "id" => variables[:id] } } }
      }
      adapter = described_class.new(callable)

      result = adapter.execute("query { product(id: $id) }", id: "gid://shopify/Product/123")

      expect(received_variables).to eq({ id: "gid://shopify/Product/123" })
      expect(result).to eq({ "data" => { "product" => { "id" => "gid://shopify/Product/123" } } })
    end

    it "returns the result from the callable" do
      expected_result = { "data" => { "shop" => { "name" => "Test Shop", "id" => "123" } } }
      callable = ->(_query, **_variables) { expected_result }
      adapter = described_class.new(callable)

      result = adapter.execute("query { shop { name id } }")

      expect(result).to eq(expected_result)
    end

    it "works with any callable object that responds to call" do
      callable_object = Class.new do
        def call(query, **variables)
          { "data" => { "query" => query, "variables" => variables } }
        end
      end.new

      adapter = described_class.new(callable_object)
      result = adapter.execute("query { test }", foo: "bar")

      expect(result).to eq({ "data" => { "query" => "query { test }", "variables" => { foo: "bar" } } })
    end

    it "propagates exceptions raised by the callable" do
      callable = ->(_query, **_variables) { raise StandardError, "Something went wrong" }
      adapter = described_class.new(callable)

      expect { adapter.execute("query { test }") }.to raise_error(StandardError, "Something went wrong")
    end
  end
end
