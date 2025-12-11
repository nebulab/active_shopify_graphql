# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Attributes do
  describe ".attribute" do
    it "defines an attribute with default path inference" do
      model_class = Class.new do
        include ActiveShopifyGraphQL::Attributes
        attribute :display_name
        define_singleton_method(:name) { "TestModel" }
      end
      loader_class = Class.new(ActiveShopifyGraphQL::Loader) { graphql_type "TestModel" }

      attrs = model_class.attributes_for_loader(loader_class)

      expect(attrs[:display_name][:path]).to eq("displayName")
    end

    it "allows custom path" do
      model_class = Class.new do
        include ActiveShopifyGraphQL::Attributes
        attribute :total, path: "totalPriceSet.shopMoney.amount"
        define_singleton_method(:name) { "TestModel" }
      end
      loader_class = Class.new(ActiveShopifyGraphQL::Loader) { graphql_type "TestModel" }

      attrs = model_class.attributes_for_loader(loader_class)

      expect(attrs[:total][:path]).to eq("totalPriceSet.shopMoney.amount")
    end

    it "stores type information" do
      model_class = Class.new do
        include ActiveShopifyGraphQL::Attributes
        attribute :count, type: :integer
        define_singleton_method(:name) { "TestModel" }
      end
      loader_class = Class.new(ActiveShopifyGraphQL::Loader) { graphql_type "TestModel" }

      attrs = model_class.attributes_for_loader(loader_class)

      expect(attrs[:count][:type]).to eq(:integer)
    end

    it "defaults type to :string" do
      model_class = Class.new do
        include ActiveShopifyGraphQL::Attributes
        attribute :name
        define_singleton_method(:name) { "TestModel" }
      end
      loader_class = Class.new(ActiveShopifyGraphQL::Loader) { graphql_type "TestModel" }

      attrs = model_class.attributes_for_loader(loader_class)

      expect(attrs[:name][:type]).to eq(:string)
    end

    it "stores null constraint" do
      model_class = Class.new do
        include ActiveShopifyGraphQL::Attributes
        attribute :required_field, null: false
        define_singleton_method(:name) { "TestModel" }
      end
      loader_class = Class.new(ActiveShopifyGraphQL::Loader) { graphql_type "TestModel" }

      attrs = model_class.attributes_for_loader(loader_class)

      expect(attrs[:required_field][:null]).to be false
    end

    it "defaults null to true" do
      model_class = Class.new do
        include ActiveShopifyGraphQL::Attributes
        attribute :optional_field
        define_singleton_method(:name) { "TestModel" }
      end
      loader_class = Class.new(ActiveShopifyGraphQL::Loader) { graphql_type "TestModel" }

      attrs = model_class.attributes_for_loader(loader_class)

      expect(attrs[:optional_field][:null]).to be true
    end

    it "stores default value" do
      model_class = Class.new do
        include ActiveShopifyGraphQL::Attributes
        attribute :status, default: "pending"
        define_singleton_method(:name) { "TestModel" }
      end
      loader_class = Class.new(ActiveShopifyGraphQL::Loader) { graphql_type "TestModel" }

      attrs = model_class.attributes_for_loader(loader_class)

      expect(attrs[:status][:default]).to eq("pending")
    end

    it "stores transform function" do
      transform_fn = ->(v) { v&.upcase }
      model_class = Class.new do
        include ActiveShopifyGraphQL::Attributes
        define_singleton_method(:name) { "TestModel" }
      end
      model_class.attribute :name, transform: transform_fn
      loader_class = Class.new(ActiveShopifyGraphQL::Loader) { graphql_type "TestModel" }

      attrs = model_class.attributes_for_loader(loader_class)

      expect(attrs[:name][:transform]).to eq(transform_fn)
    end

    it "stores raw_graphql option" do
      raw_gql = 'metafield(namespace: "custom", key: "roaster") { reference { ... on MetaObject { id } } }'
      model_class = Class.new do
        include ActiveShopifyGraphQL::Attributes
        define_singleton_method(:name) { "TestModel" }
      end
      model_class.attribute :roaster, raw_graphql: raw_gql
      loader_class = Class.new(ActiveShopifyGraphQL::Loader) { graphql_type "TestModel" }

      attrs = model_class.attributes_for_loader(loader_class)

      expect(attrs[:roaster][:raw_graphql]).to eq(raw_gql)
    end

    it "creates attr_accessor for the attribute" do
      model_class = Class.new do
        include ActiveShopifyGraphQL::Attributes
        attribute :my_field
        define_singleton_method(:name) { "TestModel" }
      end
      instance = model_class.new

      instance.my_field = "test"

      expect(instance.my_field).to eq("test")
    end
  end

  describe ".attributes_for_loader" do
    it "returns all defined attributes" do
      model_class = Class.new do
        include ActiveShopifyGraphQL::Attributes
        attribute :id
        attribute :name
        attribute :email
        define_singleton_method(:name) { "TestModel" }
      end
      loader_class = Class.new(ActiveShopifyGraphQL::Loader) { graphql_type "TestModel" }

      attrs = model_class.attributes_for_loader(loader_class)

      expect(attrs.keys).to contain_exactly(:id, :name, :email)
    end
  end
end
