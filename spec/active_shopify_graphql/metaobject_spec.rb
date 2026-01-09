# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Metaobject do
  describe ".inherited" do
    it "includes MetaobjectFields in subclasses" do
      metaobject_class = Class.new(described_class) do
        define_singleton_method(:name) { "TestMetaobject" }
      end

      expect(metaobject_class).to include(ActiveShopifyGraphQL::Model::MetaobjectFields)
    end
  end

  describe ".default_loader_class" do
    it "returns MetaobjectLoader" do
      expect(described_class.default_loader_class).to eq(ActiveShopifyGraphQL::MetaobjectLoader)
    end
  end

  describe ".metaobject_type" do
    context "when not set" do
      it "infers from class name" do
        klass = Class.new(described_class) do
          define_singleton_method(:name) { "Provider" }
        end

        expect(klass.metaobject_type).to eq("provider")
      end

      it "handles multi-word class names" do
        klass = Class.new(described_class) do
          define_singleton_method(:name) { "ServiceProvider" }
        end

        expect(klass.metaobject_type).to eq("service_provider")
      end
    end

    context "when explicitly set" do
      it "returns the set type" do
        klass = Class.new(described_class) do
          define_singleton_method(:name) { "Provider" }
        end

        klass.metaobject_type("custom_provider")

        expect(klass.metaobject_type).to eq("custom_provider")
      end
    end

    context "when class has no name" do
      it "returns nil" do
        klass = Class.new(described_class)

        expect(klass.metaobject_type).to be_nil
      end
    end
  end

  describe ".fields" do
    it "returns empty hash by default" do
      klass = Class.new(described_class)

      expect(klass.fields).to eq({})
    end

    it "inherits fields from parent" do
      parent = Class.new(described_class) do
        field :description
      end

      child = Class.new(parent)

      expect(child.fields.keys).to include(:description)
    end

    it "allows adding new fields" do
      klass = Class.new(described_class) do
        field :description
        field :rating
      end

      expect(klass.fields.keys).to contain_exactly(:description, :rating)
    end
  end

  describe ".field" do
    let(:metaobject_class) do
      Class.new(described_class) do
        define_singleton_method(:name) { "TestMetaobject" }
      end
    end

    it "stores field definition with defaults" do
      metaobject_class.field(:description)

      expect(metaobject_class.fields[:description]).to eq({
                                                            type: :string,
                                                            null: true,
                                                            default: nil,
                                                            transform: nil
                                                          })
    end

    it "stores field with custom type" do
      metaobject_class.field(:rating, type: :integer)

      expect(metaobject_class.fields[:rating][:type]).to eq(:integer)
    end

    it "stores field with null constraint" do
      metaobject_class.field(:required_field, null: false)

      expect(metaobject_class.fields[:required_field][:null]).to eq(false)
    end

    it "stores field with default value" do
      metaobject_class.field(:status, default: "active")

      expect(metaobject_class.fields[:status][:default]).to eq("active")
    end

    it "stores field with transform" do
      transform_proc = ->(val) { val.upcase }
      metaobject_class.field(:name, transform: transform_proc)

      expect(metaobject_class.fields[:name][:transform]).to eq(transform_proc)
    end

    it "defines attr_accessor for field" do
      metaobject_class.field(:description)

      instance = metaobject_class.new
      expect(instance).to respond_to(:description)
      expect(instance).to respond_to(:description=)
    end
  end
end
