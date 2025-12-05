# frozen_string_literal: true

RSpec.describe ActiveShopifyGraphQL::RecordQuery do
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
end
