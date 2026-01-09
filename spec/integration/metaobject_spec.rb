# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Metaobject Integration" do
  describe "Defining and using metaobject models" do
    let(:provider_class) do
      Class.new(ActiveShopifyGraphQL::Metaobject) do
        define_singleton_method(:name) { "Provider" }
        field :description
        field :rating, type: :integer
        field :certified, type: :boolean, default: false
      end
    end

    it "creates a proper metaobject model" do
      expect(provider_class).to be_a(Class)
      expect(provider_class).to be < ActiveShopifyGraphQL::Metaobject
    end

    it "infers metaobject type from class name" do
      expect(provider_class.metaobject_type).to eq("provider")
    end

    it "stores field definitions" do
      expect(provider_class.fields.keys).to contain_exactly(:description, :rating, :certified)
    end

    it "creates instances with field attributes" do
      instance = provider_class.new(
        id: "gid://shopify/Metaobject/123",
        description: "Test Provider",
        rating: 5,
        certified: true
      )

      expect(instance.id).to eq("gid://shopify/Metaobject/123")
      expect(instance.description).to eq("Test Provider")
      expect(instance.rating).to eq(5)
      expect(instance.certified).to eq(true)
    end

    it "can be initialized without field values" do
      instance = provider_class.new(
        id: "gid://shopify/Metaobject/123",
        description: "Test Provider"
      )

      expect(instance.certified).to be_nil
    end
  end

  describe "Metaobject loader context" do
    let(:provider_class) do
      Class.new(ActiveShopifyGraphQL::Metaobject) do
        define_singleton_method(:name) { "Provider" }
        field :name
      end
    end

    it "includes fields in loader context" do
      loader = provider_class.default_loader

      expect(loader.context.fields).to eq(provider_class.fields)
    end

    it "is recognized as metaobject" do
      loader = provider_class.default_loader

      expect(loader.context.is_metaobject?).to eq(true)
    end

    it "exposes metaobject_type" do
      loader = provider_class.default_loader

      expect(loader.context.metaobject_type).to eq("provider")
    end
  end

  describe "Query building with metaobject fields" do
    let(:provider_class) do
      Class.new(ActiveShopifyGraphQL::Metaobject) do
        define_singleton_method(:name) { "Provider" }
        field :name
        field :rating, type: :integer
      end
    end

    it "generates metaobject field nodes" do
      loader = provider_class.default_loader
      query_builder = ActiveShopifyGraphQL::Query::QueryBuilder.new(loader.context)
      field_nodes = query_builder.send(:build_metaobject_field_nodes)

      expect(field_nodes).to be_an(Array)
      expect(field_nodes.size).to eq(2)
    end

    it "generates correct GraphQL for metaobject fields" do
      loader = provider_class.default_loader
      query_builder = ActiveShopifyGraphQL::Query::QueryBuilder.new(loader.context)
      field_nodes = query_builder.send(:build_metaobject_field_nodes)
      graphql_string = field_nodes.map(&:to_s).join("\n")

      expect(graphql_string).to include('name: field(key: "name") { jsonValue }')
      expect(graphql_string).to include('rating: field(key: "rating") { jsonValue }')
    end
  end
end
