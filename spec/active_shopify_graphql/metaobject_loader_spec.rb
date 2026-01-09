# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::MetaobjectLoader do
  describe "#context" do
    it "includes fields in context" do
      metaobject_class = Class.new(ActiveShopifyGraphQL::Metaobject) do
        define_singleton_method(:name) { "Provider" }
        field :description
      end

      loader = described_class.new(metaobject_class)

      expect(loader.context.fields).to eq(metaobject_class.fields)
    end

    it "sets graphql_type to Metaobject" do
      metaobject_class = Class.new(ActiveShopifyGraphQL::Metaobject) do
        define_singleton_method(:name) { "Provider" }
      end

      loader = described_class.new(metaobject_class)

      expect(loader.context.graphql_type).to eq("Metaobject")
    end
  end

  describe "#build_collection_variables" do
    it "adds type parameter to variables" do
      metaobject_class = Class.new(ActiveShopifyGraphQL::Metaobject) do
        define_singleton_method(:name) { "ServiceProvider" }
        metaobject_type "custom_provider"
      end

      loader = described_class.new(metaobject_class)
      variables = loader.send(:build_collection_variables, {}, per_page: 10)

      expect(variables).to include(type: "custom_provider")
    end

    it "includes standard collection variables" do
      metaobject_class = Class.new(ActiveShopifyGraphQL::Metaobject) do
        define_singleton_method(:name) { "Provider" }
      end

      loader = described_class.new(metaobject_class)
      variables = loader.send(:build_collection_variables, { query: "test" }, per_page: 10)

      expect(variables).to include(first: 10, query: "query:'test'", type: "provider")
    end
  end
end
