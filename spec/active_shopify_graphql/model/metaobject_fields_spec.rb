# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Model::MetaobjectFields do
  describe ".field" do
    let(:test_model) do
      Class.new(ActiveShopifyGraphQL::Model) do
        include ActiveShopifyGraphQL::Model::MetaobjectFields

        define_singleton_method(:name) { "TestModel" }
      end
    end

    it "stores field definition in @fields" do
      test_model.field(:name)

      expect(test_model.instance_variable_get(:@fields)).to include(:name)
    end

    it "stores field with type" do
      test_model.field(:count, type: :integer)

      expect(test_model.instance_variable_get(:@fields)[:count][:type]).to eq(:integer)
    end

    it "stores field with null constraint" do
      test_model.field(:required, null: false)

      expect(test_model.instance_variable_get(:@fields)[:required][:null]).to eq(false)
    end

    it "stores field with default value" do
      test_model.field(:status, default: "active")

      expect(test_model.instance_variable_get(:@fields)[:status][:default]).to eq("active")
    end

    it "stores field with transform" do
      transform_proc = ->(val) { val.upcase }
      test_model.field(:name, transform: transform_proc)

      expect(test_model.instance_variable_get(:@fields)[:name][:transform]).to eq(transform_proc)
    end

    it "defines attr_accessor on the model" do
      test_model.field(:name)

      instance = test_model.new
      expect(instance).to respond_to(:name)
      expect(instance).to respond_to(:name=)
    end

    it "does not define attr_accessor if already defined" do
      test_model.send(:attr_accessor, :existing_field)
      test_model.field(:existing_field)

      expect { test_model.new }.not_to raise_error
    end
  end
end
