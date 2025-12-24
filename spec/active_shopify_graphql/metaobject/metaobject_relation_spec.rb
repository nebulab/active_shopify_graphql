# frozen_string_literal: true

RSpec.describe ActiveShopifyGraphQL::Metaobject::MetaobjectRelation do
  # Build a test metaobject class
  provider_class = Class.new(ActiveShopifyGraphQL::Metaobject::Base) do
    metaobject_type "provider"

    attribute :name
    attribute :description

    define_singleton_method(:name) { "Provider" }
    define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "Provider") }
  end

  before do
    stub_const("Provider", provider_class)
  end

  describe "#find" do
    it "loads a single metaobject by ID" do
      mock_client = instance_double("ShopifyClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)

      response = {
        "data" => {
          "metaobject" => {
            "id" => "gid://shopify/Metaobject/123",
            "handle" => "acme",
            "type" => "provider",
            "displayName" => "Acme Corp",
            "name" => { "key" => "name", "value" => "Acme", "jsonValue" => nil },
            "description" => { "key" => "description", "value" => "Great", "jsonValue" => nil }
          }
        }
      }

      expect(mock_client).to receive(:execute).and_return(response)

      provider = Provider.find("gid://shopify/Metaobject/123")

      expect(provider).to be_a(Provider)
      expect(provider.id).to eq("gid://shopify/Metaobject/123")
      expect(provider.name).to eq("Acme")
    end

    it "normalizes numeric IDs to GIDs" do
      mock_client = instance_double("ShopifyClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)

      response = {
        "data" => {
          "metaobject" => {
            "id" => "gid://shopify/Metaobject/123",
            "handle" => "acme",
            "type" => "provider",
            "displayName" => "Acme Corp",
            "name" => { "key" => "name", "value" => "Acme", "jsonValue" => nil },
            "description" => { "key" => "description", "value" => "Great", "jsonValue" => nil }
          }
        }
      }

      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:id]).to eq("gid://shopify/Metaobject/123")
        response
      end

      Provider.find(123)
    end

    it "raises ObjectNotFoundError when not found" do
      mock_client = instance_double("ShopifyClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)

      response = { "data" => { "metaobject" => nil } }
      expect(mock_client).to receive(:execute).and_return(response)

      expect { Provider.find(999) }.to raise_error(ActiveShopifyGraphQL::ObjectNotFoundError)
    end
  end

  describe "#where" do
    it "returns a new relation with conditions" do
      relation = Provider.all.where(display_name: "Acme")

      expect(relation.conditions).to eq(display_name: "Acme")
    end

    it "raises error when chaining multiple where clauses" do
      expect do
        Provider.where(display_name: "Acme").where(name: "Test")
      end.to raise_error(ArgumentError, /Chaining multiple where clauses/)
    end
  end

  describe "#limit" do
    it "returns a new relation with total_limit set" do
      relation = Provider.all.limit(5)

      expect(relation.total_limit).to eq(5)
    end
  end

  describe "#first" do
    it "returns the first matching record" do
      mock_client = instance_double("ShopifyClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)

      response = {
        "data" => {
          "metaobjects" => {
            "pageInfo" => { "hasNextPage" => false, "hasPreviousPage" => false },
            "nodes" => [
              {
                "id" => "gid://shopify/Metaobject/1",
                "handle" => "first",
                "type" => "provider",
                "displayName" => "First Provider",
                "name" => { "key" => "name", "value" => "First", "jsonValue" => nil },
                "description" => { "key" => "description", "value" => "Desc", "jsonValue" => nil }
              }
            ]
          }
        }
      }

      expect(mock_client).to receive(:execute).and_return(response)

      provider = Provider.all.first

      expect(provider).to be_a(Provider)
      expect(provider.name).to eq("First")
    end
  end

  describe "#find_by" do
    it "returns the first matching record for conditions" do
      mock_client = instance_double("ShopifyClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)

      response = {
        "data" => {
          "metaobjects" => {
            "pageInfo" => { "hasNextPage" => false, "hasPreviousPage" => false },
            "nodes" => [
              {
                "id" => "gid://shopify/Metaobject/1",
                "handle" => "acme",
                "type" => "provider",
                "displayName" => "Acme",
                "name" => { "key" => "name", "value" => "Acme", "jsonValue" => nil },
                "description" => { "key" => "description", "value" => "Desc", "jsonValue" => nil }
              }
            ]
          }
        }
      }

      expect(mock_client).to receive(:execute).and_return(response)

      provider = Provider.find_by(display_name: "Acme")

      expect(provider).to be_a(Provider)
      expect(provider.name).to eq("Acme")
    end
  end
end
