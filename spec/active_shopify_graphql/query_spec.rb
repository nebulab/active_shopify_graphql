# frozen_string_literal: true

RSpec.describe ActiveShopifyGraphQL::Query do
  after do
    ActiveShopifyGraphQL.reset_configuration!
  end

  describe "#initialize" do
    it "stores the graphql_type" do
      fragment_proc = -> { "fragment TestFragment on Test { id }" }
      query = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: [],
        fragment_generator: fragment_proc,
        fragment_name_proc: ->(type) { "#{type}Fragment" }
      )

      expect(query.graphql_type).to eq("Customer")
    end

    it "stores the loader_class" do
      fragment_proc = -> { "fragment TestFragment on Test { id }" }
      query = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: [],
        fragment_generator: fragment_proc,
        fragment_name_proc: ->(type) { "#{type}Fragment" }
      )

      expect(query.loader_class).to eq(ActiveShopifyGraphQL::AdminApiLoader)
    end
  end

  describe "#query_name" do
    it "returns lowercased graphql_type by default" do
      fragment_proc = -> { "fragment TestFragment on Test { id }" }
      query = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: [],
        fragment_generator: fragment_proc,
        fragment_name_proc: ->(type) { "#{type}Fragment" }
      )

      expect(query.query_name).to eq("customer")
    end

    it "accepts optional model_type parameter" do
      fragment_proc = -> { "fragment TestFragment on Test { id }" }
      query = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: [],
        fragment_generator: fragment_proc,
        fragment_name_proc: ->(type) { "#{type}Fragment" }
      )

      expect(query.query_name("Order")).to eq("order")
    end
  end

  describe "#fragment_name" do
    it "returns Fragment-suffixed name based on graphql_type" do
      fragment_proc = -> { "fragment TestFragment on Test { id }" }
      query = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: [],
        fragment_generator: fragment_proc,
        fragment_name_proc: ->(type) { "#{type}Fragment" }
      )

      expect(query.fragment_name).to eq("CustomerFragment")
    end

    it "accepts optional model_type parameter" do
      fragment_proc = -> { "fragment TestFragment on Test { id }" }
      query = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: [],
        fragment_generator: fragment_proc,
        fragment_name_proc: ->(type) { "#{type}Fragment" }
      )

      expect(query.fragment_name("Order")).to eq("OrderFragment")
    end
  end

  describe "#graphql_query" do
    it "builds complete GraphQL query with fragment" do
      fragment_proc = -> { "fragment CustomerFragment on Customer { id name }" }
      query = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: [],
        fragment_generator: fragment_proc,
        fragment_name_proc: ->(type) { "#{type}Fragment" }
      )

      result = query.graphql_query

      expect(result).to include("fragment CustomerFragment on Customer { id name }")
      expect(result).to include("query getCustomer($id: ID!)")
      expect(result).to include("customer(id: $id)")
      expect(result).to include("...CustomerFragment")
    end

    it "accepts optional model_type parameter" do
      fragment_proc = -> { "fragment OrderFragment on Order { id name }" }
      query = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: [],
        fragment_generator: fragment_proc,
        fragment_name_proc: ->(type) { "#{type}Fragment" }
      )

      result = query.graphql_query("Order")

      expect(result).to include("query getOrder($id: ID!)")
      expect(result).to include("order(id: $id)")
      expect(result).to include("...OrderFragment")
    end

    it "builds compact query when compact_queries is enabled" do
      ActiveShopifyGraphQL.configure do |config|
        config.compact_queries = true
      end

      fragment_proc = -> { "fragment CustomerFragment on Customer { id name }" }
      query = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: [],
        fragment_generator: fragment_proc,
        fragment_name_proc: ->(type) { "#{type}Fragment" }
      )

      result = query.graphql_query

      expect(result).not_to include("\n")
      expect(result).to eq("fragment CustomerFragment on Customer { id name } query getCustomer($id: ID!) { customer(id: $id) { ...CustomerFragment } }")
    end
  end

  describe "#collection_graphql_query" do
    it "builds collection query with plural query name" do
      fragment_proc = -> { "fragment CustomerFragment on Customer { id name }" }
      loader_class = class_double(ActiveShopifyGraphQL::AdminApiLoader, graphql_type: "Customer")
      query = described_class.new(
        graphql_type: "Customer",
        loader_class: loader_class,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: [],
        fragment_generator: fragment_proc,
        fragment_name_proc: ->(type) { "#{type}Fragment" }
      )

      result = query.collection_graphql_query

      expect(result).to include("fragment CustomerFragment on Customer { id name }")
      expect(result).to include("query getCustomers($query: String, $first: Int!)")
      expect(result).to include("customers(query: $query, first: $first)")
      expect(result).to include("nodes")
      expect(result).to include("...CustomerFragment")
    end

    it "accepts optional model_type parameter" do
      fragment_proc = -> { "fragment OrderFragment on Order { id name }" }
      loader_class = class_double(ActiveShopifyGraphQL::AdminApiLoader, graphql_type: "Customer")
      query = described_class.new(
        graphql_type: "Customer",
        loader_class: loader_class,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: [],
        fragment_generator: fragment_proc,
        fragment_name_proc: ->(type) { "#{type}Fragment" }
      )

      result = query.collection_graphql_query("Order")

      expect(result).to include("query getOrders($query: String, $first: Int!)")
      expect(result).to include("orders(query: $query, first: $first)")
    end

    it "builds compact query when compact_queries is enabled" do
      ActiveShopifyGraphQL.configure do |config|
        config.compact_queries = true
      end

      fragment_proc = -> { "fragment CustomerFragment on Customer { id name }" }
      loader_class = class_double(ActiveShopifyGraphQL::AdminApiLoader, graphql_type: "Customer")
      query = described_class.new(
        graphql_type: "Customer",
        loader_class: loader_class,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: [],
        fragment_generator: fragment_proc,
        fragment_name_proc: ->(type) { "#{type}Fragment" }
      )

      result = query.collection_graphql_query

      expect(result).not_to include("\n")
      expect(result).to eq("fragment CustomerFragment on Customer { id name } query getCustomers($query: String, $first: Int!) { customers(query: $query, first: $first) { nodes { ...CustomerFragment } } }")
    end
  end

  describe "#nested_connection_graphql_query" do
    it "builds query for nested connection" do
      fragment = instance_double(ActiveShopifyGraphQL::Fragment)
      allow(fragment).to receive(:fields_from_attributes).and_return("id\nname")

      parent_class = Class.new do
        def self.graphql_type_for_loader(_loader)
          "Customer"
        end
      end
      parent = parent_class.new

      query = described_class.new(
        graphql_type: "Order",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: { id: { path: "id", type: :string }, name: { path: "name", type: :string } },
        model_class: Class.new,
        included_connections: [],
        fragment_generator: -> {},
        fragment_name_proc: ->(type) { "#{type}Fragment" }
      )

      result = query.nested_connection_graphql_query("orders", { first: 10 }, parent)

      expect(result).to include("query($id: ID!)")
      expect(result).to include("customer(id: $id)")
      expect(result).to include("orders(first: 10)")
      expect(result).to include("edges")
      expect(result).to include("node")
      expect(result).to include("id")
      expect(result).to include("name")
    end

    it "builds singular connection query when connection_type is :singular" do
      parent_class = Class.new do
        def self.graphql_type_for_loader(_loader)
          "Order"
        end
      end
      parent = parent_class.new

      query = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: { id: { path: "id", type: :string } },
        model_class: Class.new,
        included_connections: [],
        fragment_generator: -> {},
        fragment_name_proc: ->(type) { "#{type}Fragment" }
      )

      result = query.nested_connection_graphql_query("customer", {}, parent, { type: :singular })

      expect(result).to include("query($id: ID!)")
      expect(result).to include("order(id: $id)")
      expect(result).to include("customer {")
      expect(result).not_to include("edges")
      expect(result).not_to include("node")
    end

    it "formats string query parameter with quotes" do
      parent_class = Class.new do
        def self.graphql_type_for_loader(_loader)
          "Customer"
        end
      end
      parent = parent_class.new

      query = described_class.new(
        graphql_type: "Order",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: { id: { path: "id", type: :string } },
        model_class: Class.new,
        included_connections: [],
        fragment_generator: -> {},
        fragment_name_proc: ->(type) { "#{type}Fragment" }
      )

      result = query.nested_connection_graphql_query("orders", { query: "status:open", first: 5 }, parent)

      expect(result).to include('query: "status:open"')
      expect(result).to include("first: 5")
    end

    it "formats enum parameter without quotes" do
      parent_class = Class.new do
        def self.graphql_type_for_loader(_loader)
          "Customer"
        end
      end
      parent = parent_class.new

      query = described_class.new(
        graphql_type: "Order",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: { id: { path: "id", type: :string } },
        model_class: Class.new,
        included_connections: [],
        fragment_generator: -> {},
        fragment_name_proc: ->(type) { "#{type}Fragment" }
      )

      result = query.nested_connection_graphql_query("orders", { sort_key: "CREATED_AT", first: 5 }, parent)

      expect(result).to include("sortKey: CREATED_AT")
      expect(result).not_to include('"CREATED_AT"')
    end

    it "converts snake_case to camelCase" do
      parent_class = Class.new do
        def self.graphql_type_for_loader(_loader)
          "Customer"
        end
      end
      parent = parent_class.new

      query = described_class.new(
        graphql_type: "Order",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: { id: { path: "id", type: :string } },
        model_class: Class.new,
        included_connections: [],
        fragment_generator: -> {},
        fragment_name_proc: ->(type) { "#{type}Fragment" }
      )

      result = query.nested_connection_graphql_query("orders", { sort_key: "CREATED_AT" }, parent)

      expect(result).to include("sortKey: CREATED_AT")
      expect(result).not_to include("sort_key")
    end

    it "builds compact query when compact_queries is enabled" do
      ActiveShopifyGraphQL.configure do |config|
        config.compact_queries = true
      end

      parent_class = Class.new do
        def self.graphql_type_for_loader(_loader)
          "Customer"
        end
      end
      parent = parent_class.new

      query = described_class.new(
        graphql_type: "Order",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: { id: { path: "id", type: :string } },
        model_class: Class.new,
        included_connections: [],
        fragment_generator: -> {},
        fragment_name_proc: ->(type) { "#{type}Fragment" }
      )

      result = query.nested_connection_graphql_query("orders", { first: 10 }, parent)

      expect(result).not_to include("\n")
      expect(result).to include("query($id: ID!) { customer(id: $id) { orders(first: 10) { edges { node { id } } } } }")
    end
  end

  describe "#connection_graphql_query" do
    it "builds connection query with variables as inline arguments" do
      query = described_class.new(
        graphql_type: "Order",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: { id: { path: "id", type: :string }, name: { path: "name", type: :string } },
        model_class: Class.new,
        included_connections: [],
        fragment_generator: -> {},
        fragment_name_proc: ->(type) { "#{type}Fragment" }
      )

      result = query.connection_graphql_query("orders", { first: 10, query: "status:open" })

      expect(result).to include("query {")
      expect(result).to include('orders(first: 10, query: "status:open")')
      expect(result).to include("edges")
      expect(result).to include("node")
      expect(result).to include("id")
      expect(result).to include("name")
    end

    it "builds singular connection query when connection_type is :singular" do
      query = described_class.new(
        graphql_type: "Shop",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: { id: { path: "id", type: :string } },
        model_class: Class.new,
        included_connections: [],
        fragment_generator: -> {},
        fragment_name_proc: ->(type) { "#{type}Fragment" }
      )

      result = query.connection_graphql_query("shop", {}, { type: :singular })

      expect(result).to include("query {")
      expect(result).to include("shop {")
      expect(result).not_to include("edges")
      expect(result).not_to include("node")
    end

    it "skips nil variables" do
      query = described_class.new(
        graphql_type: "Order",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: { id: { path: "id", type: :string } },
        model_class: Class.new,
        included_connections: [],
        fragment_generator: -> {},
        fragment_name_proc: ->(type) { "#{type}Fragment" }
      )

      result = query.connection_graphql_query("orders", { first: 10, query: nil })

      expect(result).to include("orders(first: 10)")
      expect(result).not_to include("query:")
    end

    it "formats boolean values correctly" do
      query = described_class.new(
        graphql_type: "Order",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: { id: { path: "id", type: :string } },
        model_class: Class.new,
        included_connections: [],
        fragment_generator: -> {},
        fragment_name_proc: ->(type) { "#{type}Fragment" }
      )

      result = query.connection_graphql_query("orders", { first: 10, reverse: true })

      expect(result).to include("reverse: true")
    end

    it "builds compact query when compact_queries is enabled" do
      ActiveShopifyGraphQL.configure do |config|
        config.compact_queries = true
      end

      query = described_class.new(
        graphql_type: "Order",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: { id: { path: "id", type: :string } },
        model_class: Class.new,
        included_connections: [],
        fragment_generator: -> {},
        fragment_name_proc: ->(type) { "#{type}Fragment" }
      )

      result = query.connection_graphql_query("orders", { first: 10 })

      expect(result).not_to include("\n")
      expect(result).to eq("query { orders(first: 10) { edges { node { id } } } }")
    end
  end
end
