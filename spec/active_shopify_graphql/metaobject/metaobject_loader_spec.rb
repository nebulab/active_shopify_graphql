# frozen_string_literal: true

RSpec.describe ActiveShopifyGraphQL::Metaobject::MetaobjectLoader do
  # Build a test metaobject class
  provider_class = Class.new(ActiveShopifyGraphQL::Metaobject::Base) do
    metaobject_type "provider"

    attribute :name
    attribute :description
    attribute :rating, type: :integer

    define_singleton_method(:name) { "Provider" }
    define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "Provider") }
  end

  before do
    stub_const("Provider", provider_class)
  end

  describe "#load_single" do
    it "loads a single metaobject by ID" do
      mock_client = instance_double("ShopifyClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)

      response = {
        "data" => {
          "metaobject" => {
            "id" => "gid://shopify/Metaobject/123",
            "handle" => "acme-corp",
            "type" => "provider",
            "displayName" => "Acme Corp",
            "name" => { "key" => "name", "value" => "Acme Corp", "jsonValue" => nil },
            "description" => { "key" => "description", "value" => "Best provider", "jsonValue" => nil },
            "rating" => { "key" => "rating", "value" => "5", "jsonValue" => nil }
          }
        }
      }

      expect(mock_client).to receive(:execute).and_return(response)

      loader = described_class.new(Provider)
      attributes = loader.load_single("gid://shopify/Metaobject/123")

      expect(attributes[:id]).to eq("gid://shopify/Metaobject/123")
      expect(attributes[:handle]).to eq("acme-corp")
      expect(attributes[:display_name]).to eq("Acme Corp")
      expect(attributes[:name]).to eq("Acme Corp")
      expect(attributes[:description]).to eq("Best provider")
      expect(attributes[:rating]).to eq(5)
    end

    it "returns nil when metaobject not found" do
      mock_client = instance_double("ShopifyClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)

      response = { "data" => { "metaobject" => nil } }
      expect(mock_client).to receive(:execute).and_return(response)

      loader = described_class.new(Provider)
      attributes = loader.load_single("gid://shopify/Metaobject/999")

      expect(attributes).to be_nil
    end
  end

  describe "#load_collection" do
    it "loads a collection of metaobjects" do
      mock_client = instance_double("ShopifyClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)

      response = {
        "data" => {
          "metaobjects" => {
            "pageInfo" => {
              "hasNextPage" => false,
              "hasPreviousPage" => false,
              "startCursor" => "cursor1",
              "endCursor" => "cursor2"
            },
            "nodes" => [
              {
                "id" => "gid://shopify/Metaobject/1",
                "handle" => "provider-1",
                "type" => "provider",
                "displayName" => "Provider One",
                "name" => { "key" => "name", "value" => "Provider One", "jsonValue" => nil },
                "description" => { "key" => "description", "value" => "First", "jsonValue" => nil },
                "rating" => { "key" => "rating", "value" => "4", "jsonValue" => nil }
              },
              {
                "id" => "gid://shopify/Metaobject/2",
                "handle" => "provider-2",
                "type" => "provider",
                "displayName" => "Provider Two",
                "name" => { "key" => "name", "value" => "Provider Two", "jsonValue" => nil },
                "description" => { "key" => "description", "value" => "Second", "jsonValue" => nil },
                "rating" => { "key" => "rating", "value" => "5", "jsonValue" => nil }
              }
            ]
          }
        }
      }

      expect(mock_client).to receive(:execute).and_return(response)

      loader = described_class.new(Provider)
      relation = ActiveShopifyGraphQL::Metaobject::MetaobjectRelation.new(Provider)
      result = loader.load_collection(conditions: {}, per_page: 10, relation: relation)

      expect(result).to be_a(ActiveShopifyGraphQL::Metaobject::MetaobjectPaginatedResult)
      expect(result.size).to eq(2)

      first_provider = result.first
      expect(first_provider.id).to eq("gid://shopify/Metaobject/1")
      expect(first_provider.name).to eq("Provider One")
      expect(first_provider.rating).to eq(4)

      second_provider = result.to_a[1]
      expect(second_provider.id).to eq("gid://shopify/Metaobject/2")
      expect(second_provider.name).to eq("Provider Two")
      expect(second_provider.rating).to eq(5)
    end

    it "includes query parameter when conditions are provided" do
      mock_client = instance_double("ShopifyClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)

      response = {
        "data" => {
          "metaobjects" => {
            "pageInfo" => { "hasNextPage" => false, "hasPreviousPage" => false },
            "nodes" => []
          }
        }
      }

      expect(mock_client).to receive(:execute) do |query, **_variables|
        expect(query).to include('query: "display_name')
        response
      end

      loader = described_class.new(Provider)
      relation = ActiveShopifyGraphQL::Metaobject::MetaobjectRelation.new(Provider)
      loader.load_collection(conditions: { display_name: "Acme" }, per_page: 10, relation: relation)
    end
  end
end
