# frozen_string_literal: true

# Integration test demonstrating the intended usage of Metaobjects
RSpec.describe "Metaobject Integration", type: :integration do
  # This simulates what users would define in their application
  # Note: id, handle, type, and display_name are built-in and should NOT be redefined as attributes
  application_metaobject_base = Class.new(ActiveShopifyGraphQL::Metaobject::Base) do
    # Add common custom methods here if needed
  end

  provider_class = Class.new(application_metaobject_base) do
    metaobject_type "provider"

    attribute :name
    attribute :description
    attribute :website_url, key: "website_url"
    attribute :rating, type: :integer
    attribute :verified, type: :boolean

    define_singleton_method(:name) { "Provider" }
    define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "Provider") }
  end

  before do
    stub_const("ApplicationShopifyMetaobject", application_metaobject_base)
    stub_const("Provider", provider_class)
  end

  describe "finding metaobjects" do
    it "finds a metaobject by ID using Model.find" do
      mock_client = instance_double("ShopifyClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)

      response = {
        "data" => {
          "metaobject" => {
            "id" => "gid://shopify/Metaobject/12345",
            "handle" => "acme-corp",
            "type" => "provider",
            "displayName" => "Acme Corporation",
            "name" => { "key" => "name", "value" => "Acme Corporation", "jsonValue" => nil },
            "description" => { "key" => "description", "value" => "Leading provider of everything", "jsonValue" => nil },
            "website_url" => { "key" => "website_url", "value" => "https://acme.com", "jsonValue" => nil },
            "rating" => { "key" => "rating", "value" => "5", "jsonValue" => nil },
            "verified" => { "key" => "verified", "value" => "true", "jsonValue" => nil }
          }
        }
      }

      expect(mock_client).to receive(:execute).and_return(response)

      provider = Provider.find("gid://shopify/Metaobject/12345")

      expect(provider.id).to eq("gid://shopify/Metaobject/12345")
      expect(provider.handle).to eq("acme-corp")
      expect(provider.display_name).to eq("Acme Corporation")
      expect(provider.name).to eq("Acme Corporation")
      expect(provider.description).to eq("Leading provider of everything")
      expect(provider.website_url).to eq("https://acme.com")
      expect(provider.rating).to eq(5)
      expect(provider.verified).to eq(true)
    end

    it "queries metaobjects using Model.where" do
      mock_client = instance_double("ShopifyClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)

      response = {
        "data" => {
          "metaobjects" => {
            "pageInfo" => {
              "hasNextPage" => false,
              "hasPreviousPage" => false,
              "startCursor" => nil,
              "endCursor" => nil
            },
            "nodes" => [
              {
                "id" => "gid://shopify/Metaobject/1",
                "handle" => "verified-provider",
                "type" => "provider",
                "displayName" => "Verified Provider",
                "name" => { "key" => "name", "value" => "Verified Provider", "jsonValue" => nil },
                "description" => { "key" => "description", "value" => "A verified provider", "jsonValue" => nil },
                "website_url" => { "key" => "website_url", "value" => "https://verified.com", "jsonValue" => nil },
                "rating" => { "key" => "rating", "value" => "4", "jsonValue" => nil },
                "verified" => { "key" => "verified", "value" => "true", "jsonValue" => nil }
              }
            ]
          }
        }
      }

      expect(mock_client).to receive(:execute).and_return(response)

      providers = Provider.where(verified: true).to_a

      expect(providers.size).to eq(1)
      expect(providers.first.name).to eq("Verified Provider")
      expect(providers.first.verified).to eq(true)
    end

    it "supports find_by for finding single matching record" do
      mock_client = instance_double("ShopifyClient")
      allow(ActiveShopifyGraphQL.configuration).to receive(:admin_api_client).and_return(mock_client)

      response = {
        "data" => {
          "metaobjects" => {
            "pageInfo" => { "hasNextPage" => false, "hasPreviousPage" => false },
            "nodes" => [
              {
                "id" => "gid://shopify/Metaobject/1",
                "handle" => "my-handle",
                "type" => "provider",
                "displayName" => "My Provider",
                "name" => { "key" => "name", "value" => "My Provider", "jsonValue" => nil },
                "description" => { "key" => "description", "value" => "Desc", "jsonValue" => nil },
                "website_url" => { "key" => "website_url", "value" => nil, "jsonValue" => nil },
                "rating" => { "key" => "rating", "value" => "3", "jsonValue" => nil },
                "verified" => { "key" => "verified", "value" => "false", "jsonValue" => nil }
              }
            ]
          }
        }
      }

      expect(mock_client).to receive(:execute).and_return(response)

      provider = Provider.find_by(handle: "my-handle")

      expect(provider).to be_a(Provider)
      expect(provider.handle).to eq("my-handle")
    end

    it "returns nil from find_by when no match" do
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

      expect(mock_client).to receive(:execute).and_return(response)

      provider = Provider.find_by(handle: "nonexistent")

      expect(provider).to be_nil
    end
  end
end
