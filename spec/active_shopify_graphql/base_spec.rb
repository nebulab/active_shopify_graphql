# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Base do
  describe "#initialize" do
    it "accepts attributes hash and assigns them" do
      model_class = Class.new do
        include ActiveShopifyGraphQL::Base

        attribute :id
        attribute :name
        define_singleton_method(:name) { "TestModel" }
        define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "TestModel") }
      end
      model_class.graphql_type("TestModel")

      instance = model_class.new(id: "123", name: "Test")

      expect(instance.id).to eq("123")
      expect(instance.name).to eq("Test")
    end

    it "extracts connection cache from attributes if present" do
      model_class = Class.new do
        include ActiveShopifyGraphQL::Base

        attribute :id
        define_singleton_method(:name) { "TestModel" }
        define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "TestModel") }
      end
      model_class.graphql_type("TestModel")
      stub_const("Order", build_order_class)
      model_class.has_many_connected :orders, default_arguments: { first: 10 }
      mock_orders = [build_order_class.new(id: "1")]

      instance = model_class.new(id: "123", _connection_cache: { orders: mock_orders })

      expect(instance.instance_variable_get(:@_connection_cache)).to eq({ orders: mock_orders })
    end

    it "works with empty attributes" do
      model_class = Class.new do
        include ActiveShopifyGraphQL::Base

        attribute :id
        define_singleton_method(:name) { "TestModel" }
        define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "TestModel") }
      end
      model_class.graphql_type("TestModel")

      expect { model_class.new }.not_to raise_error
    end
  end
end
