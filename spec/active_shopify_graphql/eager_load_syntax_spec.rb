# frozen_string_literal: true

require "spec_helper"

module EagerLoadSyntaxSpec
  class Variant
    def self.graphql_type_for_loader(_)
      "Variant"
    end

    def self.attributes_for_loader(_)
      { id: { path: "id", type: :string } }
    end
  end

  class Product
    include ActiveShopifyGraphQL::Connections

    def self.graphql_type_for_loader(_)
      "Product"
    end

    def self.attributes_for_loader(_)
      { id: { path: "id", type: :string } }
    end
  end
end

RSpec.describe "Eager Load Syntax" do
  let(:product_class) { EagerLoadSyntaxSpec::Product }
  let(:variant_class_name) { "EagerLoadSyntaxSpec::Variant" }

  it "generates valid GraphQL syntax when eager loading with minimal parameters" do
    product_class.connection :variants, class_name: variant_class_name, default_arguments: { first: 10 }, eager_load: true

    loader = ActiveShopifyGraphQL::Loader.new(product_class, included_connections: [:variants])
    query = loader.graphql_query

    expect(query).to include("variants(first: 10) {")
    expect(query).not_to include("sortKey:")
    expect(query).not_to include("reverse:")
  end

  it "generates valid GraphQL syntax when eager loading with all parameters" do
    product_class.connection :variants, class_name: variant_class_name, default_arguments: { first: 10, sort_key: :TITLE, reverse: true }, eager_load: true

    loader = ActiveShopifyGraphQL::Loader.new(product_class, included_connections: [:variants])
    query = loader.graphql_query

    expect(query).to include("variants(first: 10, sortKey: TITLE, reverse: true) {")
  end

  it "generates valid GraphQL syntax for string parameters" do
    product_class.connection :variants, class_name: variant_class_name, default_arguments: { first: 10, query: "title:test" }, eager_load: true

    loader = ActiveShopifyGraphQL::Loader.new(product_class, included_connections: [:variants])
    query = loader.graphql_query

    expect(query).to include('variants(first: 10, query: "title:test") {')
  end
end
