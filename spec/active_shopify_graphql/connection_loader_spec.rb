# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::ConnectionLoader do
  describe "#load_records" do
    it "loads records from root-level connection and returns empty array for empty response" do
      context = build_context(graphql_type: "Order")
      loader_instance = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(loader_instance).to receive(:perform_graphql_query).and_return({ "data" => { "orders" => { "edges" => [] } } })
      loader = described_class.new(context, loader_instance: loader_instance)

      result = loader.load_records("orders", { first: 10 })

      expect(result).to eq([])
    end

    it "returns empty array when response is nil" do
      context = build_context(graphql_type: "Order")
      loader_instance = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(loader_instance).to receive(:perform_graphql_query).and_return(nil)
      loader = described_class.new(context, loader_instance: loader_instance)

      result = loader.load_records("orders", { first: 10 })

      expect(result).to eq([])
    end

    it "loads records using parent query for nested connection" do
      parent_class = Class.new do
        attr_accessor :id

        define_singleton_method(:graphql_type_for_loader) { |_| "Customer" }
        define_singleton_method(:graphql_type) { "Customer" }
      end
      parent = parent_class.new
      parent.id = "gid://shopify/Customer/123"
      context = build_context(graphql_type: "Order")
      loader_instance = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(loader_instance).to receive(:perform_graphql_query).and_return({ "data" => { "customer" => { "orders" => { "edges" => [] } } } })
      loader = described_class.new(context, loader_instance: loader_instance)

      result = loader.load_records("orders", { first: 10 }, parent, { nested: true })

      expect(result).to eq([])
      expect(loader_instance).to have_received(:perform_graphql_query) do |query, **vars|
        expect(query).to include("customer(id: $id)")
        expect(query).to include("orders")
        expect(vars[:id]).to eq("gid://shopify/Customer/123")
      end
    end

    it "normalizes numeric ID to GID format for nested connection" do
      parent_class = Class.new do
        attr_accessor :id

        define_singleton_method(:graphql_type_for_loader) { |_| "Customer" }
        define_singleton_method(:graphql_type) { "Customer" }
      end
      parent = parent_class.new
      parent.id = 123
      context = build_context(graphql_type: "Order")
      loader_instance = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(loader_instance).to receive(:perform_graphql_query).and_return({ "data" => { "customer" => { "orders" => { "edges" => [] } } } })
      loader = described_class.new(context, loader_instance: loader_instance)

      loader.load_records("orders", {}, parent, { nested: true })

      expect(loader_instance).to have_received(:perform_graphql_query) do |_query, **vars|
        expect(vars[:id]).to eq("gid://shopify/Customer/123")
      end
    end

    it "uses gid attribute if available on parent" do
      parent_class = Class.new do
        attr_accessor :id, :gid

        define_singleton_method(:graphql_type_for_loader) { |_| "Customer" }
        define_singleton_method(:graphql_type) { "Customer" }
      end
      parent = parent_class.new
      parent.id = 456
      parent.gid = "gid://shopify/Customer/789"
      context = build_context(graphql_type: "Order")
      loader_instance = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(loader_instance).to receive(:perform_graphql_query).and_return({ "data" => { "customer" => { "orders" => { "edges" => [] } } } })
      loader = described_class.new(context, loader_instance: loader_instance)

      loader.load_records("orders", {}, parent, { nested: true })

      expect(loader_instance).to have_received(:perform_graphql_query) do |_query, **vars|
        expect(vars[:id]).to eq("gid://shopify/Customer/789")
      end
    end

    it "returns empty array when nested response is nil" do
      parent_class = Class.new do
        attr_accessor :id

        define_singleton_method(:graphql_type_for_loader) { |_| "Customer" }
      end
      parent = parent_class.new
      parent.id = "gid://shopify/Customer/123"
      context = build_context(graphql_type: "Order")
      loader_instance = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(loader_instance).to receive(:perform_graphql_query).and_return(nil)
      loader = described_class.new(context, loader_instance: loader_instance)

      result = loader.load_records("orders", {}, parent, { nested: true })

      expect(result).to eq([])
    end
  end

  private

  def build_context(graphql_type: "Order", attributes: {}, model_class: nil, included_connections: [])
    model_class ||= Class.new do
      define_singleton_method(:graphql_type_for_loader) { |_| graphql_type }
      define_singleton_method(:graphql_type) { graphql_type }
      define_singleton_method(:connections) { {} }
    end

    ActiveShopifyGraphQL::LoaderContext.new(
      graphql_type: graphql_type,
      loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
      defined_attributes: attributes.empty? ? { id: { path: "id", type: :string } } : attributes,
      model_class: model_class,
      included_connections: included_connections
    )
  end
end
