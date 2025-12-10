# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::LoaderContext do
  describe "#initialize" do
    it "stores all required parameters" do
      model_class = Class.new { define_singleton_method(:connections) { {} } }

      context = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: { id: { path: "id", type: :string } },
        model_class: model_class,
        included_connections: [:orders]
      )

      expect(context.graphql_type).to eq("Customer")
      expect(context.loader_class).to eq(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      expect(context.defined_attributes).to eq({ id: { path: "id", type: :string } })
      expect(context.model_class).to eq(model_class)
      expect(context.included_connections).to eq([:orders])
    end

    it "defaults included_connections to empty array" do
      model_class = Class.new { define_singleton_method(:connections) { {} } }

      context = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: {},
        model_class: model_class
      )

      expect(context.included_connections).to eq([])
    end

    it "wraps single connection in array" do
      model_class = Class.new { define_singleton_method(:connections) { {} } }

      context = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: {},
        model_class: model_class,
        included_connections: :orders
      )

      expect(context.included_connections).to eq([:orders])
    end
  end

  describe "#with_connections" do
    it "creates new context with different connections" do
      model_class = Class.new { define_singleton_method(:connections) { {} } }
      original_context = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: { id: { path: "id", type: :string } },
        model_class: model_class,
        included_connections: [:orders]
      )

      new_context = original_context.with_connections([:addresses])

      expect(new_context.included_connections).to eq([:addresses])
      expect(new_context.graphql_type).to eq("Customer")
      expect(original_context.included_connections).to eq([:orders])
    end
  end

  describe "#for_model" do
    it "creates new context for different model" do
      model_class1 = Class.new do
        define_singleton_method(:connections) { {} }
        define_singleton_method(:graphql_type_for_loader) { |_| "Customer" }
        define_singleton_method(:attributes_for_loader) { |_| { id: { path: "id", type: :string } } }
      end
      model_class2 = Class.new do
        define_singleton_method(:connections) { {} }
        define_singleton_method(:graphql_type_for_loader) { |_| "Order" }
        define_singleton_method(:attributes_for_loader) { |_| { id: { path: "id", type: :string }, name: { path: "name", type: :string } } }
      end
      original_context = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: { id: { path: "id", type: :string } },
        model_class: model_class1
      )

      new_context = original_context.for_model(model_class2)

      expect(new_context.graphql_type).to eq("Order")
      expect(new_context.model_class).to eq(model_class2)
      expect(new_context.defined_attributes.keys).to contain_exactly(:id, :name)
    end
  end

  describe "#query_name" do
    it "returns lowercase graphql_type" do
      model_class = Class.new { define_singleton_method(:connections) { {} } }
      context = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: {},
        model_class: model_class
      )

      expect(context.query_name).to eq("customer")
    end
  end

  describe "#fragment_name" do
    it "returns graphql_type with Fragment suffix" do
      model_class = Class.new { define_singleton_method(:connections) { {} } }
      context = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: {},
        model_class: model_class
      )

      expect(context.fragment_name).to eq("CustomerFragment")
    end
  end

  describe "#connections" do
    it "returns model class connections" do
      model_class = Class.new { define_singleton_method(:connections) { { orders: { class_name: "Order" } } } }
      context = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: {},
        model_class: model_class
      )

      expect(context.connections).to eq({ orders: { class_name: "Order" } })
    end
  end

  describe "equality" do
    it "considers contexts with same values as equal" do
      model_class = Class.new { define_singleton_method(:connections) { {} } }
      attrs = { id: { path: "id", type: :string } }
      context1 = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: attrs,
        model_class: model_class,
        included_connections: [:orders]
      )
      context2 = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: attrs,
        model_class: model_class,
        included_connections: [:orders]
      )

      expect(context1).to eq(context2)
    end

    it "considers contexts with different values as not equal" do
      model_class = Class.new { define_singleton_method(:connections) { {} } }
      context1 = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: {},
        model_class: model_class
      )
      context2 = described_class.new(
        graphql_type: "Order",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: {},
        model_class: model_class
      )

      expect(context1).not_to eq(context2)
    end
  end
end
