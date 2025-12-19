# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Query::Node do
  describe "#to_s" do
    it "raises NotImplementedError" do
      node = described_class.new(name: "test")

      expect { node.to_s }.to raise_error(NotImplementedError)
    end
  end

  describe "#add_child" do
    it "adds a child node" do
      parent = described_class.new(name: "address")
      child = ActiveShopifyGraphQL::Query::Node::Field.new(name: "city")

      parent.add_child(child)

      expect(parent.children).to contain_exactly(child)
    end

    it "returns the added child" do
      parent = described_class.new(name: "address")
      child = ActiveShopifyGraphQL::Query::Node::Field.new(name: "city")

      result = parent.add_child(child)

      expect(result).to eq(child)
    end
  end

  describe "#has_children?" do
    it "returns false for node without children" do
      node = described_class.new(name: "id")

      expect(node.has_children?).to be false
    end

    it "returns true for node with children" do
      child = ActiveShopifyGraphQL::Query::Node::Field.new(name: "id")
      parent = described_class.new(name: "address", children: [child])

      expect(parent.has_children?).to be true
    end
  end
end

RSpec.describe ActiveShopifyGraphQL::Query::Node::Field do
  describe "#to_s" do
    it "renders simple field" do
      node = described_class.new(name: "id")

      expect(node.to_s).to eq("id")
    end

    it "renders field with alias" do
      node = described_class.new(name: "metafield", alias_name: "customField")

      expect(node.to_s).to include("customField: metafield")
    end

    it "renders field with nested children" do
      child = described_class.new(name: "city")
      parent = described_class.new(name: "address", children: [child])

      result = parent.to_s

      expect(result).to include("address")
      expect(result).to include("city")
    end
  end
end

RSpec.describe ActiveShopifyGraphQL::Query::Node::Connection do
  describe "#to_s" do
    it "renders connection with nodes structure" do
      child = ActiveShopifyGraphQL::Query::Node::Field.new(name: "id")
      connection = described_class.new(name: "orders", arguments: { first: 10 }, children: [child])

      result = connection.to_s

      expect(result).to include("orders")
      expect(result).to include("nodes")
      expect(result).to include("id")
    end
  end
end

RSpec.describe ActiveShopifyGraphQL::Query::Node::Singular do
  describe "#to_s" do
    it "renders singular association" do
      child = ActiveShopifyGraphQL::Query::Node::Field.new(name: "city")
      node = described_class.new(name: "defaultAddress", children: [child])

      result = node.to_s

      expect(result).to include("defaultAddress")
      expect(result).to include("city")
      expect(result).not_to include("nodes")
    end
  end
end

RSpec.describe ActiveShopifyGraphQL::Query::Node::Fragment do
  describe "#to_s" do
    it "renders fragment with type" do
      child = ActiveShopifyGraphQL::Query::Node::Field.new(name: "id")
      fragment = described_class.new(name: "CustomerFragment", arguments: { on: "Customer" }, children: [child])

      result = fragment.to_s

      expect(result).to include("fragment CustomerFragment on Customer")
      expect(result).to include("id")
    end
  end
end

RSpec.describe ActiveShopifyGraphQL::Query::Node::Raw do
  describe "#to_s" do
    it "renders raw GraphQL string directly" do
      raw_gql = 'metafield(namespace: "custom", key: "roaster") { reference { ... on MetaObject { id } } }'
      node = described_class.new(name: "raw", arguments: { raw_graphql: raw_gql })

      result = node.to_s

      expect(result).to eq(raw_gql)
    end
  end
end
