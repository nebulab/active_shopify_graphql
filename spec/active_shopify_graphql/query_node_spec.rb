# frozen_string_literal: true

require "spec_helper"

RSpec.describe QueryNode do
  describe "#initialize" do
    it "creates a field node with name" do
      node = described_class.new(name: "id", node_type: :field)

      expect(node.name).to eq("id")
      expect(node.node_type).to eq(:field)
    end

    it "creates a node with alias" do
      node = described_class.new(name: "metafield", alias_name: "customMetafield", node_type: :field)

      expect(node.alias_name).to eq("customMetafield")
    end

    it "creates a node with arguments" do
      node = described_class.new(name: "orders", arguments: { first: 10 }, node_type: :connection)

      expect(node.arguments).to eq({ first: 10 })
    end

    it "creates a node with children" do
      child = described_class.new(name: "id", node_type: :field)
      parent = described_class.new(name: "address", node_type: :field, children: [child])

      expect(parent.children).to contain_exactly(child)
    end
  end

  describe "#add_child" do
    it "adds a child node" do
      parent = described_class.new(name: "address", node_type: :field)
      child = described_class.new(name: "city", node_type: :field)

      parent.add_child(child)

      expect(parent.children).to contain_exactly(child)
    end

    it "returns the added child" do
      parent = described_class.new(name: "address", node_type: :field)
      child = described_class.new(name: "city", node_type: :field)

      result = parent.add_child(child)

      expect(result).to eq(child)
    end
  end

  describe "#has_children?" do
    it "returns false for node without children" do
      node = described_class.new(name: "id", node_type: :field)

      expect(node.has_children?).to be false
    end

    it "returns true for node with children" do
      child = described_class.new(name: "id", node_type: :field)
      parent = described_class.new(name: "address", node_type: :field, children: [child])

      expect(parent.has_children?).to be true
    end
  end

  describe "#to_s" do
    it "renders simple field" do
      node = described_class.new(name: "id", node_type: :field)

      expect(node.to_s).to eq("id")
    end

    it "renders field with alias" do
      node = described_class.new(name: "metafield", alias_name: "customField", node_type: :field)

      expect(node.to_s).to include("customField: metafield")
    end

    it "renders field with nested children" do
      child = described_class.new(name: "city", node_type: :field)
      parent = described_class.new(name: "address", node_type: :field, children: [child])

      result = parent.to_s

      expect(result).to include("address")
      expect(result).to include("city")
    end

    it "renders connection with edges and node structure" do
      child = described_class.new(name: "id", node_type: :field)
      connection = described_class.new(name: "orders", arguments: { first: 10 }, node_type: :connection, children: [child])

      result = connection.to_s

      expect(result).to include("orders")
      expect(result).to include("edges")
      expect(result).to include("node")
      expect(result).to include("id")
    end

    it "renders fragment with type" do
      child = described_class.new(name: "id", node_type: :field)
      fragment = described_class.new(name: "CustomerFragment", arguments: { on: "Customer" }, node_type: :fragment, children: [child])

      result = fragment.to_s

      expect(result).to include("fragment CustomerFragment on Customer")
      expect(result).to include("id")
    end

    it "renders raw GraphQL string directly" do
      raw_gql = 'metafield(namespace: "custom", key: "roaster") { reference { ... on MetaObject { id } } }'
      node = described_class.new(name: "raw", arguments: { raw_graphql: raw_gql }, node_type: :raw)

      result = node.to_s

      expect(result).to eq(raw_gql)
    end
  end
end
