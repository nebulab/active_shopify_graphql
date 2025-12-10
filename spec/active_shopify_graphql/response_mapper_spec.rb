# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::ResponseMapper do
  def build_context(graphql_type: "Customer", attributes: {}, model_class: nil, included_connections: [])
    model_class ||= Class.new do
      define_singleton_method(:connections) { {} }
    end

    ActiveShopifyGraphQL::LoaderContext.new(
      graphql_type: graphql_type,
      loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
      defined_attributes: attributes,
      model_class: model_class,
      included_connections: included_connections
    )
  end

  describe "#map_response" do
    it "maps simple flat attributes from response" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        email: { path: "email", type: :string, null: true }
      }
      context = build_context(attributes: attributes)
      mapper = described_class.new(context)
      response_data = {
        "data" => {
          "customer" => {
            "id" => "gid://shopify/Customer/123",
            "email" => "test@example.com"
          }
        }
      }

      result = mapper.map_response(response_data)

      expect(result).to eq({
                             id: "gid://shopify/Customer/123",
                             email: "test@example.com"
                           })
    end

    it "maps nested attributes using dotted paths" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        amount: { path: "totalPriceSet.shopMoney.amount", type: :string, null: true }
      }
      context = build_context(graphql_type: "Order", attributes: attributes)
      mapper = described_class.new(context)
      response_data = {
        "data" => {
          "order" => {
            "id" => "gid://shopify/Order/456",
            "totalPriceSet" => {
              "shopMoney" => { "amount" => "99.99" }
            }
          }
        }
      }

      result = mapper.map_response(response_data)

      expect(result).to eq({
                             id: "gid://shopify/Order/456",
                             amount: "99.99"
                           })
    end

    it "coerces integer type values" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        count: { path: "orderCount", type: :integer, null: true }
      }
      context = build_context(attributes: attributes)
      mapper = described_class.new(context)
      response_data = {
        "data" => {
          "customer" => {
            "id" => "123",
            "orderCount" => "42"
          }
        }
      }

      result = mapper.map_response(response_data)

      expect(result[:count]).to eq(42)
    end

    it "coerces boolean type values" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        active: { path: "active", type: :boolean, null: true }
      }
      context = build_context(attributes: attributes)
      mapper = described_class.new(context)
      response_data = {
        "data" => {
          "customer" => {
            "id" => "123",
            "active" => "true"
          }
        }
      }

      result = mapper.map_response(response_data)

      expect(result[:active]).to be true
    end

    it "applies transform functions" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        tags: { path: "tags", type: :string, null: true, transform: ->(v) { v&.join(", ") } }
      }
      context = build_context(attributes: attributes)
      mapper = described_class.new(context)
      response_data = {
        "data" => {
          "customer" => {
            "id" => "123",
            "tags" => %w[vip premium]
          }
        }
      }

      result = mapper.map_response(response_data)

      expect(result[:tags]).to eq("vip, premium")
    end

    it "uses default values when field is nil" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        status: { path: "status", type: :string, null: true, default: "pending" }
      }
      context = build_context(attributes: attributes)
      mapper = described_class.new(context)
      response_data = {
        "data" => {
          "customer" => {
            "id" => "123",
            "status" => nil
          }
        }
      }

      result = mapper.map_response(response_data)

      expect(result[:status]).to eq("pending")
    end

    it "preserves arrays regardless of type specification" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        tags: { path: "tags", type: :string, null: true }
      }
      context = build_context(attributes: attributes)
      mapper = described_class.new(context)
      response_data = {
        "data" => {
          "customer" => {
            "id" => "123",
            "tags" => %w[tag1 tag2 tag3]
          }
        }
      }

      result = mapper.map_response(response_data)

      expect(result[:tags]).to eq(%w[tag1 tag2 tag3])
    end

    it "raises error for null values when null is not allowed" do
      attributes = {
        required_field: { path: "requiredField", type: :string, null: false }
      }
      context = build_context(attributes: attributes)
      mapper = described_class.new(context)
      response_data = {
        "data" => {
          "customer" => {
            "requiredField" => nil
          }
        }
      }

      expect { mapper.map_response(response_data) }.to raise_error(ArgumentError, /cannot be null/)
    end

    it "returns empty hash when root data is nil" do
      attributes = {
        id: { path: "id", type: :string, null: false }
      }
      context = build_context(attributes: attributes)
      mapper = described_class.new(context)
      response_data = { "data" => { "customer" => nil } }

      result = mapper.map_response(response_data)

      expect(result).to eq({})
    end
  end

  describe "#map_node_to_attributes" do
    it "maps node data directly without root path traversal" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        name: { path: "displayName", type: :string, null: true }
      }
      context = build_context(attributes: attributes)
      mapper = described_class.new(context)
      node_data = {
        "id" => "gid://shopify/Customer/123",
        "displayName" => "John Doe"
      }

      result = mapper.map_node_to_attributes(node_data)

      expect(result).to eq({
                             id: "gid://shopify/Customer/123",
                             name: "John Doe"
                           })
    end

    it "returns empty hash for nil node data" do
      attributes = {
        id: { path: "id", type: :string, null: false }
      }
      context = build_context(attributes: attributes)
      mapper = described_class.new(context)

      result = mapper.map_node_to_attributes(nil)

      expect(result).to eq({})
    end
  end
end
