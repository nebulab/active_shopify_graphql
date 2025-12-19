# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Query::Tree do
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

  describe ".build_current_customer_query" do
    it "generates query without ID parameter" do
      context = build_context(
        graphql_type: "Customer",
        attributes: { id: { path: "id", type: :string }, email: { path: "email", type: :string } }
      )

      query = described_class.build_current_customer_query(context)

      expect(query).to include("query getCurrentCustomer")
      expect(query).not_to include("$id")
      expect(query).to include("customer {")
      expect(query).to include("...CustomerFragment")
    end

    it "includes fragment definition" do
      context = build_context(
        graphql_type: "Customer",
        attributes: { id: { path: "id", type: :string } }
      )

      query = described_class.build_current_customer_query(context)

      expect(query).to include("fragment CustomerFragment on Customer")
    end

    it "includes connection fields when included_connections is set" do
      order_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "Order" }
        define_singleton_method(:attributes_for_loader) do |_|
          {
            id: { path: "id", type: :string },
            name: { path: "name", type: :string }
          }
        end
        define_singleton_method(:connections) { {} }
      end
      stub_const("Order", order_class)
      model_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "Customer" }
        define_singleton_method(:attributes_for_loader) do |_|
          {
            id: { path: "id", type: :string },
            email: { path: "email", type: :string }
          }
        end
        define_singleton_method(:connections) do
          {
            orders: {
              class_name: "Order",
              query_name: "orders",
              type: :connection,
              default_arguments: { first: 10, sort_key: "CREATED_AT" }
            }
          }
        end
      end
      context = build_context(
        graphql_type: "Customer",
        attributes: { id: { path: "id", type: :string }, email: { path: "email", type: :string } },
        model_class: model_class,
        included_connections: [:orders]
      )

      query = described_class.build_current_customer_query(context)

      expect(query).to include("query getCurrentCustomer")
      expect(query).to include("orders(")
      expect(query).to include("edges {")
      expect(query).to include("node {")
    end

    it "allows custom query_name override" do
      context = build_context(
        graphql_type: "Customer",
        attributes: { id: { path: "id", type: :string } }
      )

      query = described_class.build_current_customer_query(context, query_name: "me")

      expect(query).to include("me {")
    end
  end

  describe ".build_paginated_collection_query" do
    it "generates paginated collection query with pageInfo" do
      context = build_context(
        graphql_type: "ProductVariant",
        attributes: { id: { path: "id", type: :string }, sku: { path: "sku", type: :string } }
      )
      variables = { query: "sku:*", first: 50 }

      query = described_class.build_paginated_collection_query(context, query_name: "productVariants", variables: variables)

      expect(query).to include("query getProductVariants")
      expect(query).to include("productVariants")
      expect(query).to include("pageInfo")
      expect(query).to include("hasNextPage")
      expect(query).to include("hasPreviousPage")
      expect(query).to include("startCursor")
      expect(query).to include("endCursor")
      expect(query).to include("nodes")
      expect(query).to include("...ProductVariantFragment")
    end

    it "includes query parameter in field signature" do
      context = build_context(
        graphql_type: "Customer",
        attributes: { id: { path: "id", type: :string } }
      )
      variables = { query: "email:test@example.com", first: 100 }

      query = described_class.build_paginated_collection_query(context, query_name: "customers", variables: variables)

      expect(query).to include('query: "email:test@example.com"')
      expect(query).to include("first: 100")
    end

    it "includes after cursor when provided" do
      context = build_context(
        graphql_type: "Customer",
        attributes: { id: { path: "id", type: :string } }
      )
      variables = { query: "", first: 50, after: "cursor123" }

      query = described_class.build_paginated_collection_query(context, query_name: "customers", variables: variables)

      expect(query).to include('after: "cursor123"')
    end

    it "includes before cursor when provided" do
      context = build_context(
        graphql_type: "Customer",
        attributes: { id: { path: "id", type: :string } }
      )
      variables = { query: "", last: 50, before: "cursor456" }

      query = described_class.build_paginated_collection_query(context, query_name: "customers", variables: variables)

      expect(query).to include('before: "cursor456"')
    end

    it "properly quotes cursor values" do
      context = build_context(
        graphql_type: "ProductVariant",
        attributes: { id: { path: "id", type: :string } }
      )
      variables = { query: "", first: 10, after: "eyJsYXN0X2lkIjo0NTk1MjYxNTU3OTk0NywibGFzdF92YWx1ZSI6IjQ1OTUyNjE1NTc5OTQ3In0=" }

      query = described_class.build_paginated_collection_query(context, query_name: "productVariants", variables: variables)

      expect(query).to include('after: "eyJsYXN0X2lkIjo0NTk1MjYxNTU3OTk0NywibGFzdF92YWx1ZSI6IjQ1OTUyNjE1NTc5OTQ3In0="')
    end
  end

  describe ".fragment_name" do
    it "returns graphql_type with Fragment suffix" do
      expect(described_class.fragment_name("Customer")).to eq("CustomerFragment")
      expect(described_class.fragment_name("Order")).to eq("OrderFragment")
    end
  end
end
