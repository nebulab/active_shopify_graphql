# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Model::Attributes do
  describe ".attribute" do
    it "defines an attribute with default path inference" do
      model_class = build_minimal_model(name: "TestModel", graphql_type: "TestModel", attributes: [:display_name])
      loader_class = Class.new(ActiveShopifyGraphQL::Loader) { graphql_type "TestModel" }

      attrs = model_class.attributes_for_loader(loader_class)

      expect(attrs[:display_name][:path]).to eq("displayName")
    end

    it "allows custom path" do
      model_class = build_minimal_model(name: "TestModel", graphql_type: "TestModel", attributes: [])
      model_class.attribute :total, path: "totalPriceSet.shopMoney.amount"
      loader_class = Class.new(ActiveShopifyGraphQL::Loader) { graphql_type "TestModel" }

      attrs = model_class.attributes_for_loader(loader_class)

      expect(attrs[:total][:path]).to eq("totalPriceSet.shopMoney.amount")
    end

    it "stores type information" do
      model_class = build_minimal_model(name: "TestModel", graphql_type: "TestModel", attributes: [])
      model_class.attribute :count, type: :integer
      loader_class = Class.new(ActiveShopifyGraphQL::Loader) { graphql_type "TestModel" }

      attrs = model_class.attributes_for_loader(loader_class)

      expect(attrs[:count][:type]).to eq(:integer)
    end

    it "defaults type to :string" do
      model_class = build_minimal_model(name: "TestModel", graphql_type: "TestModel", attributes: [:name])
      loader_class = Class.new(ActiveShopifyGraphQL::Loader) { graphql_type "TestModel" }

      attrs = model_class.attributes_for_loader(loader_class)

      expect(attrs[:name][:type]).to eq(:string)
    end

    it "stores null constraint" do
      model_class = build_minimal_model(name: "TestModel", graphql_type: "TestModel", attributes: [])
      model_class.attribute :required_field, null: false
      loader_class = Class.new(ActiveShopifyGraphQL::Loader) { graphql_type "TestModel" }

      attrs = model_class.attributes_for_loader(loader_class)

      expect(attrs[:required_field][:null]).to be false
    end

    it "defaults null to true" do
      model_class = build_minimal_model(name: "TestModel", graphql_type: "TestModel", attributes: [:optional_field])
      loader_class = Class.new(ActiveShopifyGraphQL::Loader) { graphql_type "TestModel" }

      attrs = model_class.attributes_for_loader(loader_class)

      expect(attrs[:optional_field][:null]).to be true
    end

    it "stores default value" do
      model_class = build_minimal_model(name: "TestModel", graphql_type: "TestModel", attributes: [])
      model_class.attribute :status, default: "pending"
      loader_class = Class.new(ActiveShopifyGraphQL::Loader) { graphql_type "TestModel" }

      attrs = model_class.attributes_for_loader(loader_class)

      expect(attrs[:status][:default]).to eq("pending")
    end

    it "stores transform function" do
      transform_fn = ->(v) { v&.upcase }
      model_class = build_minimal_model(name: "TestModel", graphql_type: "TestModel", attributes: [])
      model_class.attribute :name, transform: transform_fn
      loader_class = Class.new(ActiveShopifyGraphQL::Loader) { graphql_type "TestModel" }

      attrs = model_class.attributes_for_loader(loader_class)

      expect(attrs[:name][:transform]).to eq(transform_fn)
    end

    it "stores raw_graphql option" do
      raw_gql = 'metafield(namespace: "custom", key: "roaster") { reference { ... on MetaObject { id } } }'
      model_class = build_minimal_model(name: "TestModel", graphql_type: "TestModel", attributes: [])
      model_class.attribute :roaster, raw_graphql: raw_gql
      loader_class = Class.new(ActiveShopifyGraphQL::Loader) { graphql_type "TestModel" }

      attrs = model_class.attributes_for_loader(loader_class)

      expect(attrs[:roaster][:raw_graphql]).to eq(raw_gql)
    end

    it "creates attr_accessor for the attribute" do
      model_class = build_minimal_model(name: "TestModel", graphql_type: "TestModel", attributes: [:my_field])
      instance = model_class.new

      instance.my_field = "test"

      expect(instance.my_field).to eq("test")
    end
  end

  describe ".attributes_for_loader" do
    it "returns all defined attributes" do
      model_class = build_minimal_model(name: "TestModel", graphql_type: "TestModel", attributes: %i[id name email])
      loader_class = Class.new(ActiveShopifyGraphQL::Loader) { graphql_type "TestModel" }

      attrs = model_class.attributes_for_loader(loader_class)

      expect(attrs.keys).to contain_exactly(:id, :name, :email)
    end
  end
end
