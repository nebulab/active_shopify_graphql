# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Query::QueryBuilder do
  def build_context(graphql_type: "Customer", attributes: {}, model_class: nil, included_connections: [])
    model_class ||= Class.new do
      define_singleton_method(:connections) { {} }
    end

    default_attrs = attributes.empty? ? { id: { path: "id", type: :string } } : attributes

    ActiveShopifyGraphQL::LoaderContext.new(
      graphql_type: graphql_type,
      loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
      defined_attributes: default_attrs,
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

    it "uses nodes connection type by default" do
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
      expect(query).to include("nodes {")
      expect(query).to include("pageInfo")
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
      expect(query).to include("nodes {")
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

  describe "#build_fragment" do
    it "creates fragment with correct type" do
      context = build_context(
        graphql_type: "Customer",
        attributes: { id: { path: "id", type: :string } }
      )
      builder = described_class.new(context)

      fragment = builder.build_fragment

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

      fragment = builder.build_fragment.to_s

      expect(fragment).to include("id")
      expect(fragment).to include("email")
    end

    it "generates aliased fields for simple paths where attr_name differs from path" do
      context = build_context(
        graphql_type: "Customer",
        attributes: {
          id: { path: "id", type: :string },
          first_name: { path: "firstName", type: :string }
        }
      )
      builder = described_class.new(context)

      fragment = builder.build_fragment.to_s

      expect(fragment).to include("first_name: firstName")
    end

    it "does not generate alias when attr_name matches path" do
      context = build_context(
        graphql_type: "Customer",
        attributes: {
          id: { path: "id", type: :string }
        }
      )
      builder = described_class.new(context)

      fragment = builder.build_fragment.to_s

      expect(fragment).to include("id")
      expect(fragment).not_to include("id: id")
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

      fragment = builder.build_fragment.to_s

      expect(fragment).to include("totalPriceSet")
      expect(fragment).to include("shopMoney")
      expect(fragment).to include("amount")
    end

    it "raises error when attributes are empty" do
      empty_context = ActiveShopifyGraphQL::LoaderContext.new(
        graphql_type: "Empty",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new { define_singleton_method(:connections) { {} } },
        included_connections: []
      )
      builder = described_class.new(empty_context)

      expect { builder.build_fragment }.to raise_error(NotImplementedError, /must define attributes/)
    end
  end

  describe "#build_field_nodes" do
    it "returns array of Query::Node subclasses" do
      context = build_context(
        graphql_type: "Customer",
        attributes: { id: { path: "id", type: :string } }
      )
      builder = described_class.new(context)

      nodes = builder.build_field_nodes

      expect(nodes).to be_an(Array)
      expect(nodes.first).to be_a(ActiveShopifyGraphQL::Query::Node)
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

      fragment = builder.build_fragment.to_s

      expect(fragment).to include("jsonValue")
    end

    it "includes raw GraphQL string with alias in fragment" do
      raw_gql = 'metafield(namespace: "custom", key: "roaster") { reference { ... on MetaObject { id } } }'
      context = build_context(
        graphql_type: "Product",
        attributes: {
          id: { path: "id", type: :string },
          roaster: { path: "roaster", type: :string, raw_graphql: raw_gql }
        }
      )
      builder = described_class.new(context)

      fragment = builder.build_fragment.to_s

      # Raw GraphQL should be prefixed with alias (attr_name)
      expect(fragment).to include("roaster: #{raw_gql}")
    end

    it "handles multiple raw GraphQL attributes with aliases" do
      raw_gql1 = 'metafield(namespace: "custom", key: "roaster") { reference { ... on MetaObject { id } } }'
      raw_gql2 = 'metafield(namespace: "custom", key: "origin") { value }'
      context = build_context(
        graphql_type: "Product",
        attributes: {
          id: { path: "id", type: :string },
          roaster: { path: "roaster", type: :string, raw_graphql: raw_gql1 },
          origin: { path: "origin", type: :string, raw_graphql: raw_gql2 }
        }
      )
      builder = described_class.new(context)

      fragment = builder.build_fragment.to_s

      expect(fragment).to include("roaster: #{raw_gql1}")
      expect(fragment).to include("origin: #{raw_gql2}")
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

    it "generates alias when connection original_name differs from query_name" do
      order_class = Class.new do
        define_singleton_method(:name) { "Order" }
        define_singleton_method(:connections) { {} }
      end
      stub_const("Order", order_class)
      order_class.define_singleton_method(:attributes_for_loader) { |_| { id: { path: "id", type: :string } } }

      model_class = Class.new do
        define_singleton_method(:connections) do
          {
            recent_orders: {
              class_name: "Order",
              query_name: "orders",
              original_name: :recent_orders,
              type: :connection,
              default_arguments: { first: 5, reverse: true }
            }
          }
        end
      end
      context = build_context(
        graphql_type: "Customer",
        attributes: { id: { path: "id", type: :string } },
        model_class: model_class,
        included_connections: [:recent_orders]
      )
      builder = described_class.new(context)

      fragment = builder.build_fragment.to_s

      expect(fragment).to include("recent_orders: orders")
    end

    it "does not generate alias when original_name matches query_name" do
      order_class = Class.new do
        define_singleton_method(:name) { "Order" }
        define_singleton_method(:connections) { {} }
      end
      stub_const("Order", order_class)
      order_class.define_singleton_method(:attributes_for_loader) { |_| { id: { path: "id", type: :string } } }

      model_class = Class.new do
        define_singleton_method(:connections) do
          {
            orders: {
              class_name: "Order",
              query_name: "orders",
              original_name: :orders,
              type: :connection,
              default_arguments: { first: 10 }
            }
          }
        end
      end
      context = build_context(
        graphql_type: "Customer",
        attributes: { id: { path: "id", type: :string } },
        model_class: model_class,
        included_connections: [:orders]
      )
      builder = described_class.new(context)

      fragment = builder.build_fragment.to_s

      expect(fragment).to include("orders(first: 10)")
      expect(fragment).not_to include("orders: orders")
    end

    it "handles multiple connections with same query_name but different aliases" do
      order_class = Class.new do
        define_singleton_method(:name) { "Order" }
        define_singleton_method(:connections) { {} }
      end
      stub_const("Order", order_class)
      order_class.define_singleton_method(:attributes_for_loader) { |_| { id: { path: "id", type: :string } } }

      model_class = Class.new do
        define_singleton_method(:connections) do
          {
            orders: {
              class_name: "Order",
              query_name: "orders",
              original_name: :orders,
              type: :connection,
              default_arguments: { first: 2 }
            },
            recent_orders: {
              class_name: "Order",
              query_name: "orders",
              original_name: :recent_orders,
              type: :connection,
              default_arguments: { first: 5, reverse: true, sort_key: "CREATED_AT" }
            }
          }
        end
      end
      context = build_context(
        graphql_type: "Customer",
        attributes: { id: { path: "id", type: :string } },
        model_class: model_class,
        included_connections: %i[orders recent_orders]
      )
      builder = described_class.new(context)

      fragment = builder.build_fragment.to_s

      expect(fragment).to include("orders(first: 2)")
      expect(fragment).to include("recent_orders: orders(first: 5")
    end
  end
end
