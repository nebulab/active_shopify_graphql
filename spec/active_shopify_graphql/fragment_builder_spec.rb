# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::FragmentBuilder do
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

  describe "#build" do
    it "creates fragment with correct type" do
      context = build_context(
        graphql_type: "Customer",
        attributes: { id: { path: "id", type: :string } }
      )
      builder = described_class.new(context)

      fragment = builder.build

      expect(fragment.to_s).to include("fragment CustomerFragment on Customer")
    end

    it "includes simple field nodes from attributes" do
      context = build_context(
        graphql_type: "Customer",
        attributes: {
          id: { path: "id", type: :string },
          email: { path: "email", type: :string }
        }
      )
      builder = described_class.new(context)

      fragment = builder.build.to_s

      expect(fragment).to include("id")
      expect(fragment).to include("email")
    end

    it "includes nested field nodes from dotted paths" do
      context = build_context(
        graphql_type: "Order",
        attributes: {
          id: { path: "id", type: :string },
          amount: { path: "totalPriceSet.shopMoney.amount", type: :string }
        }
      )
      builder = described_class.new(context)

      fragment = builder.build.to_s

      expect(fragment).to include("totalPriceSet")
      expect(fragment).to include("shopMoney")
      expect(fragment).to include("amount")
    end

    it "raises error when attributes are empty" do
      context = build_context(graphql_type: "Empty", attributes: {})
      builder = described_class.new(context)

      expect { builder.build }.to raise_error(NotImplementedError, /must define attributes/)
    end
  end

  describe "#build_field_nodes" do
    it "returns array of QueryNode objects" do
      context = build_context(
        graphql_type: "Customer",
        attributes: { id: { path: "id", type: :string } }
      )
      builder = described_class.new(context)

      nodes = builder.build_field_nodes

      expect(nodes).to be_an(Array)
      expect(nodes.first).to be_a(QueryNode)
    end

    it "handles metafield attributes with correct alias syntax" do
      context = build_context(
        graphql_type: "Product",
        attributes: {
          id: { path: "id", type: :string },
          custom_value: {
            path: "customValueMetafield.value",
            type: :string,
            is_metafield: true,
            metafield_alias: "customValueMetafield",
            metafield_namespace: "custom",
            metafield_key: "my_value"
          }
        }
      )
      builder = described_class.new(context)

      nodes = builder.build_field_nodes

      metafield_node = nodes.find { |n| n.alias_name == "customValueMetafield" }
      expect(metafield_node).not_to be_nil
      expect(metafield_node.name).to eq("metafield")
    end

    it "uses jsonValue field for json type metafields" do
      context = build_context(
        graphql_type: "Product",
        attributes: {
          id: { path: "id", type: :string },
          json_data: {
            path: "jsonDataMetafield.jsonValue",
            type: :json,
            is_metafield: true,
            metafield_alias: "jsonDataMetafield",
            metafield_namespace: "custom",
            metafield_key: "json_data"
          }
        }
      )
      builder = described_class.new(context)

      fragment = builder.build.to_s

      expect(fragment).to include("jsonValue")
    end
  end

  describe "#build_connection_nodes" do
    it "returns empty array when no connections are included" do
      context = build_context(
        graphql_type: "Customer",
        attributes: { id: { path: "id", type: :string } },
        included_connections: []
      )
      builder = described_class.new(context)

      nodes = builder.build_connection_nodes

      expect(nodes).to eq([])
    end
  end
end
