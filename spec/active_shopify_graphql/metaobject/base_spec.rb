# frozen_string_literal: true

RSpec.describe ActiveShopifyGraphQL::Metaobject::Base do
  # Build a test metaobject class
  let_class = Class.new(ActiveShopifyGraphQL::Metaobject::Base) do
    metaobject_type "provider"

    attribute :name
    attribute :description
    attribute :rating, type: :integer
    attribute :active, type: :boolean

    define_singleton_method(:name) { "Provider" }
    define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "Provider") }
  end

  before do
    stub_const("Provider", let_class)
  end

  describe ".metaobject_type" do
    it "returns the configured metaobject type" do
      expect(Provider.metaobject_type).to eq("provider")
    end

    it "infers metaobject type from class name if not explicitly set" do
      blog_post_class = Class.new(ActiveShopifyGraphQL::Metaobject::Base) do
        attribute :title
        attribute :content

        define_singleton_method(:name) { "BlogPost" }
        define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "BlogPost") }
      end

      stub_const("BlogPost", blog_post_class)

      expect(BlogPost.metaobject_type).to eq("blog_post")
    end

    it "can explicitly override inferred type" do
      custom_class = Class.new(ActiveShopifyGraphQL::Metaobject::Base) do
        metaobject_type "custom_override"

        define_singleton_method(:name) { "CustomClass" }
        define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "CustomClass") }
      end

      stub_const("CustomClass", custom_class)

      expect(CustomClass.metaobject_type).to eq("custom_override")
    end
  end

  describe ".graphql_type" do
    it "always returns Metaobject" do
      expect(Provider.graphql_type).to eq("Metaobject")
    end
  end

  describe ".metaobject_attributes" do
    it "returns all defined attributes with their configs" do
      attrs = Provider.metaobject_attributes

      expect(attrs.keys).to contain_exactly(:name, :description, :rating, :active)
      expect(attrs[:name][:key]).to eq("name")
      expect(attrs[:name][:type]).to eq(:string)
      expect(attrs[:rating][:type]).to eq(:integer)
      expect(attrs[:active][:type]).to eq(:boolean)
    end
  end

  describe "instance" do
    it "has accessors for base attributes" do
      provider = Provider.new

      provider.id = "gid://shopify/Metaobject/123"
      provider.handle = "my-provider"
      provider.display_name = "My Provider"

      expect(provider.id).to eq("gid://shopify/Metaobject/123")
      expect(provider.handle).to eq("my-provider")
      expect(provider.display_name).to eq("My Provider")
    end

    it "has accessors for custom attributes" do
      provider = Provider.new

      provider.name = "Acme Corp"
      provider.description = "A great provider"
      provider.rating = 5
      provider.active = true

      expect(provider.name).to eq("Acme Corp")
      expect(provider.description).to eq("A great provider")
      expect(provider.rating).to eq(5)
      expect(provider.active).to eq(true)
    end
  end

  describe ".all" do
    it "returns a MetaobjectRelation" do
      relation = Provider.all

      expect(relation).to be_a(ActiveShopifyGraphQL::Metaobject::MetaobjectRelation)
      expect(relation.model_class).to eq(Provider)
    end
  end

  describe ".where" do
    it "returns a MetaobjectRelation with conditions" do
      relation = Provider.where(display_name: "Acme")

      expect(relation).to be_a(ActiveShopifyGraphQL::Metaobject::MetaobjectRelation)
      expect(relation.conditions).to eq(display_name: "Acme")
    end
  end
end
