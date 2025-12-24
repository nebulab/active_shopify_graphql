# frozen_string_literal: true

RSpec.describe "Metaobject Connections Integration" do
  provider_class = Class.new(ActiveShopifyGraphQL::Metaobject::Base) do
    metaobject_type "provider"

    attribute :name
    attribute :description
    attribute :rating, type: :integer

    define_singleton_method(:name) { "Provider" }
    define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "Provider") }
  end

  product_class = Class.new(ActiveShopifyGraphQL::Model) do
    graphql_type "Product"

    attribute :id
    attribute :title

    has_one_connected_metaobject :provider,
                                 class_name: "Provider",
                                 namespace: "custom",
                                 key: "provider"

    define_singleton_method(:name) { "Product" }
    define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "Product") }
  end

  before do
    stub_const("Provider", provider_class)
    stub_const("Product", product_class)
  end

  describe "defining metaobject connections" do
    it "stores connection configuration" do
      config = Product.connections[:provider]

      expect(config[:type]).to eq(:metaobject_reference)
      expect(config[:class_name]).to eq("Provider")
      expect(config[:metafield_namespace]).to eq("custom")
      expect(config[:metafield_key]).to eq("provider")
    end

    it "creates accessor methods" do
      product = Product.new(id: "gid://shopify/Product/123")

      expect(product).to respond_to(:provider)
      expect(product).to respond_to(:provider=)
    end
  end

  describe "eager loading with includes" do
    it "generates correct GraphQL query with metaobject reference" do
      mock_client = instance_double("ShopifyClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)

      expect(mock_client).to receive(:execute) do |query, **_variables|
        # Should include metafield with reference and metaobject fields
        expect(query).to include('provider: metafield(namespace: "custom", key: "provider")')
        expect(query).to include("reference")
        expect(query).to include("... on Metaobject")
        expect(query).to include("handle")
        expect(query).to include("displayName")
        expect(query).to include('field(key: "name")')
        expect(query).to include('field(key: "description")')
        expect(query).to include('field(key: "rating")')

        {
          "data" => {
            "product" => {
              "id" => "gid://shopify/Product/123",
              "title" => "Test Product",
              "provider" => {
                "reference" => {
                  "id" => "gid://shopify/Metaobject/456",
                  "handle" => "acme-corp",
                  "type" => "provider",
                  "displayName" => "Acme Corp",
                  "name" => { "key" => "name", "value" => "Acme Corp", "jsonValue" => nil },
                  "description" => { "key" => "description", "value" => "Best provider", "jsonValue" => nil },
                  "rating" => { "key" => "rating", "value" => "5", "jsonValue" => nil }
                }
              }
            }
          }
        }
      end

      product = Product.includes(:provider).find("gid://shopify/Product/123")

      expect(product.title).to eq("Test Product")
      expect(product.provider).to be_a(Provider)
      expect(product.provider.id).to eq("gid://shopify/Metaobject/456")
      expect(product.provider.name).to eq("Acme Corp")
      expect(product.provider.description).to eq("Best provider")
      expect(product.provider.rating).to eq(5)
    end

    it "handles nil metaobject reference" do
      mock_client = instance_double("ShopifyClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)

      expect(mock_client).to receive(:execute).and_return(
        {
          "data" => {
            "product" => {
              "id" => "gid://shopify/Product/123",
              "title" => "Test Product",
              "provider" => nil
            }
          }
        }
      )

      product = Product.includes(:provider).find("gid://shopify/Product/123")

      expect(product.provider).to be_nil
    end
  end

  describe "lazy loading" do
    it "raises NotImplementedError when accessing without includes" do
      product = Product.new(id: "gid://shopify/Product/123")

      expect do
        product.provider
      end.to raise_error(NotImplementedError, /Lazy loading for metaobject connections not yet implemented/)
    end
  end

  describe "manual assignment for testing" do
    it "allows setting metaobject connection" do
      product = Product.new(id: "gid://shopify/Product/123")
      provider = Provider.new(
        id: "gid://shopify/Metaobject/456",
        name: "Test Provider"
      )

      product.provider = provider

      expect(product.provider).to eq(provider)
      expect(product.provider.name).to eq("Test Provider")
    end
  end
end
