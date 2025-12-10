# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::QueryTree do
  def build_context(graphql_type: "Customer", attributes: {}, model_class: nil, included_connections: [])
    model_class ||= Class.new do
      define_singleton_method(:connections) { {} }
    end

    ActiveShopifyGraphQL::LoaderContext.new(
      graphql_type: graphql_type,
      loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
      defined_attributes: attributes.empty? ? { id: { path: "id", type: :string } } : attributes,
      model_class: model_class,
      included_connections: included_connections
    )
  end

  describe ".build_single_record_query" do
    it "generates query with correct structure" do
      context = build_context(
        graphql_type: "Customer",
        attributes: { id: { path: "id", type: :string }, email: { path: "email", type: :string } }
      )

      query = described_class.build_single_record_query(context)

      expect(query).to include("query getCustomer($id: ID!)")
      expect(query).to include("customer(id: $id)")
      expect(query).to include("...CustomerFragment")
    end

    it "includes fragment definition" do
      context = build_context(
        graphql_type: "Customer",
        attributes: { id: { path: "id", type: :string } }
      )

      query = described_class.build_single_record_query(context)

      expect(query).to include("fragment CustomerFragment on Customer")
    end
  end

  describe ".build_collection_query" do
    it "generates collection query with correct structure" do
      context = build_context(
        graphql_type: "Customer",
        attributes: { id: { path: "id", type: :string } }
      )
      variables = { query: "email:test@example.com", first: 100 }

      query = described_class.build_collection_query(context, query_name: "customers", variables: variables)

      expect(query).to include("query getCustomers")
      expect(query).to include("customers")
    end

    it "uses nodes_only connection type by default" do
      context = build_context(
        graphql_type: "Customer",
        attributes: { id: { path: "id", type: :string } }
      )
      variables = { first: 100 }

      query = described_class.build_collection_query(context, query_name: "customers", variables: variables)

      expect(query).to include("nodes")
    end
  end

  describe ".build_connection_query" do
    it "generates connection query with correct structure" do
      context = build_context(
        graphql_type: "Order",
        attributes: { id: { path: "id", type: :string } }
      )
      variables = { first: 10 }

      query = described_class.build_connection_query(context, query_name: "orders", variables: variables)

      expect(query).to include("orders")
      expect(query).to include("edges")
      expect(query).to include("node")
    end

    it "supports nested queries with parent_query" do
      context = build_context(
        graphql_type: "Order",
        attributes: { id: { path: "id", type: :string } }
      )
      variables = { first: 10 }

      query = described_class.build_connection_query(
        context,
        query_name: "orders",
        variables: variables,
        parent_query: "customer(id: $id)"
      )

      expect(query).to include("customer(id: $id)")
      expect(query).to include("orders")
    end
  end

  describe ".query_name" do
    it "returns lowercase graphql_type" do
      expect(described_class.query_name("Customer")).to eq("customer")
      expect(described_class.query_name("ProductVariant")).to eq("productvariant")
    end
  end

  describe ".fragment_name" do
    it "returns graphql_type with Fragment suffix" do
      expect(described_class.fragment_name("Customer")).to eq("CustomerFragment")
      expect(described_class.fragment_name("Order")).to eq("OrderFragment")
    end
  end
end
