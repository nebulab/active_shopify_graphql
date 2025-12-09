# frozen_string_literal: true

RSpec.describe ActiveShopifyGraphQL::Fragment do
  after do
    ActiveShopifyGraphQL.reset_configuration!
  end

  describe "#initialize" do
    it "stores the graphql_type" do
      fragment = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: []
      )

      expect(fragment.graphql_type).to eq("Customer")
    end

    it "stores the loader_class" do
      fragment = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: []
      )

      expect(fragment.loader_class).to eq(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
    end

    it "stores the defined_attributes" do
      attributes = { id: { path: "id", type: :string } }
      fragment = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: attributes,
        model_class: Class.new,
        included_connections: []
      )

      expect(fragment.defined_attributes).to eq(attributes)
    end

    it "stores the model_class" do
      model = Class.new
      fragment = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: {},
        model_class: model,
        included_connections: []
      )

      expect(fragment.model_class).to eq(model)
    end

    it "stores the included_connections" do
      connections = %i[orders addresses]
      fragment = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: connections
      )

      expect(fragment.included_connections).to eq(connections)
    end
  end

  describe "#to_s" do
    it "generates complete fragment with attributes" do
      attributes = {
        id: { path: "id", type: :string },
        name: { path: "displayName", type: :string }
      }
      fragment = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: attributes,
        model_class: Class.new,
        included_connections: []
      )

      result = fragment.to_s

      expect(result).to include("fragment CustomerFragment on Customer {")
      expect(result).to include("id")
      expect(result).to include("displayName")
      expect(result).to include("}")
    end

    it "raises error when no attributes defined" do
      fragment = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: []
      )

      expect { fragment.to_s }.to raise_error(NotImplementedError, /must define attributes/)
    end

    it "generates compact fragment when compact_queries is enabled" do
      ActiveShopifyGraphQL.configure do |config|
        config.compact_queries = true
      end

      attributes = { id: { path: "id", type: :string } }
      fragment = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: attributes,
        model_class: Class.new,
        included_connections: []
      )

      result = fragment.to_s

      expect(result).not_to include("\n")
      expect(result).to eq("fragment CustomerFragment on Customer { id }")
    end
  end

  describe "#fields_from_attributes" do
    it "builds simple fields from flat attributes" do
      attributes = {
        id: { path: "id", type: :string },
        email: { path: "email", type: :string }
      }
      fragment = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: attributes,
        model_class: Class.new,
        included_connections: []
      )

      result = fragment.fields_from_attributes

      expect(result).to include("id")
      expect(result).to include("email")
    end

    it "builds nested fields from dotted paths" do
      attributes = {
        id: { path: "id", type: :string },
        amount: { path: "totalPriceSet.shopMoney.amount", type: :string }
      }
      fragment = described_class.new(
        graphql_type: "Order",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: attributes,
        model_class: Class.new,
        included_connections: []
      )

      result = fragment.fields_from_attributes

      expect(result).to include("id")
      expect(result).to include("totalPriceSet")
      expect(result).to include("shopMoney")
      expect(result).to include("amount")
    end

    it "merges common nested paths efficiently" do
      attributes = {
        shop_amount: { path: "totalPriceSet.shopMoney.amount", type: :string },
        shop_currency: { path: "totalPriceSet.shopMoney.currencyCode", type: :string }
      }
      fragment = described_class.new(
        graphql_type: "Order",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: attributes,
        model_class: Class.new,
        included_connections: []
      )

      result = fragment.fields_from_attributes

      # Should have one totalPriceSet block with one shopMoney block containing both fields
      expect(result).to include("totalPriceSet")
      expect(result).to include("shopMoney")
      expect(result).to include("amount")
      expect(result).to include("currencyCode")
      # Count occurrences - should only have one of each parent
      expect(result.scan(/totalPriceSet/).count).to eq(1)
      expect(result.scan(/shopMoney/).count).to eq(1)
    end

    it "handles metafield attributes" do
      attributes = {
        id: { path: "id", type: :string },
        custom_field: {
          path: "metafield",
          type: :string,
          is_metafield: true,
          metafield_alias: "customField",
          metafield_namespace: "custom",
          metafield_key: "field1"
        }
      }
      fragment = described_class.new(
        graphql_type: "Product",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: attributes,
        model_class: Class.new,
        included_connections: []
      )

      result = fragment.fields_from_attributes

      expect(result).to include("id")
      expect(result).to include('customField: metafield(namespace: "custom", key: "field1")')
      expect(result).to include("value")
    end

    it "uses jsonValue for json type metafields" do
      attributes = {
        json_field: {
          path: "metafield",
          type: :json,
          is_metafield: true,
          metafield_alias: "jsonData",
          metafield_namespace: "custom",
          metafield_key: "data"
        }
      }
      fragment = described_class.new(
        graphql_type: "Product",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: attributes,
        model_class: Class.new,
        included_connections: []
      )

      result = fragment.fields_from_attributes

      expect(result).to include('jsonData: metafield(namespace: "custom", key: "data")')
      expect(result).to include("jsonValue")
      expect(result).not_to include("value")
    end
  end

  describe "#normalize_includes" do
    it "normalizes symbol includes to hash format" do
      fragment = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: []
      )

      result = fragment.normalize_includes(%i[orders addresses])

      expect(result).to eq({ orders: [], addresses: [] })
    end

    it "normalizes string includes to hash format" do
      fragment = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: []
      )

      result = fragment.normalize_includes(["orders"])

      expect(result).to eq({ orders: [] })
    end

    it "keeps hash includes as-is" do
      fragment = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: []
      )

      result = fragment.normalize_includes([{ orders: [:line_items] }])

      expect(result).to eq({ orders: [:line_items] })
    end

    it "merges multiple includes for the same association" do
      fragment = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: []
      )

      result = fragment.normalize_includes([
                                             { orders: [:line_items] },
                                             { orders: [:shipping_address] }
                                           ])

      expect(result).to eq({ orders: %i[line_items shipping_address] })
    end

    it "handles mixed symbol and hash includes" do
      fragment = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: []
      )

      result = fragment.normalize_includes([
                                             :orders,
                                             { addresses: [:country] }
                                           ])

      expect(result).to eq({ orders: [], addresses: [:country] })
    end
  end

  describe "#connection_fields" do
    it "returns empty string when no connections included" do
      fragment = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: { id: { path: "id", type: :string } },
        model_class: Class.new,
        included_connections: []
      )

      result = fragment.connection_fields

      expect(result).to eq("")
    end

    it "returns empty string when model doesn't support connections" do
      model = Class.new
      fragment = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: { id: { path: "id", type: :string } },
        model_class: model,
        included_connections: [:orders]
      )

      result = fragment.connection_fields

      expect(result).to eq("")
    end
  end
end
