# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Model::GraphqlTypeResolver do
  describe ".graphql_type" do
    it "returns explicitly set type" do
      klass = Class.new(ActiveShopifyGraphQL::Model) do
        define_singleton_method(:name) { "Customer" }
      end
      klass.graphql_type("Customer")

      expect(klass.graphql_type).to eq("Customer")
    end

    it "infers type from class name when not explicitly set" do
      klass = Class.new(ActiveShopifyGraphQL::Model) do
        define_singleton_method(:name) { "Customer" }
      end

      expect(klass.graphql_type).to eq("Customer")
    end

    it "infers demodulized type from namespaced class name" do
      klass = Class.new(ActiveShopifyGraphQL::Model) do
        define_singleton_method(:name) { "MyApp::Customer" }
      end

      expect(klass.graphql_type).to eq("Customer")
    end
  end
end
