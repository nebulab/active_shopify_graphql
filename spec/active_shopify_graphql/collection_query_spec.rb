# frozen_string_literal: true

RSpec.describe ActiveShopifyGraphQL::CollectionQuery do
  def record_query_stub
    query_stub = instance_double(ActiveShopifyGraphQL::RecordQuery)
    allow(query_stub).to receive(:query_name, &:downcase)
    query_stub
  end

  def mock_loader_instance
    loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
    allow(loader).to receive(:perform_graphql_query)
    loader
  end

  after do
    ActiveShopifyGraphQL.reset_configuration!
  end

  describe "#initialize" do
    it "stores the graphql_type" do
      query_builder = instance_double(ActiveShopifyGraphQL::RecordQuery)
      # record_query_stub is used instead
      fragment = instance_double(ActiveShopifyGraphQL::Fragment, to_s: "fragment CustomerFragment on Customer { id }", fragment_name: "CustomerFragment")
      map_response_proc = ->(_response) { {} }
      collection_query = described_class.new(
        graphql_type: "Customer",
        query_builder: query_builder,
        record_query: record_query_stub,
        fragment: fragment,
        map_response_proc: map_response_proc,
        loader_instance: mock_loader_instance
      )

      expect(collection_query.graphql_type).to eq("Customer")
    end
  end

  describe "#execute" do
    it "executes collection query and returns mapped results" do
      loader = mock_loader_instance

      query_builder = instance_double(ActiveShopifyGraphQL::RecordQuery)
      # record_query_stub is used instead
      fragment = instance_double(ActiveShopifyGraphQL::Fragment, to_s: "fragment CustomerFragment on Customer { id }", fragment_name: "CustomerFragment")
      map_response_proc = ->(response) { response.dig("data", "customer") }
      collection_query = described_class.new(
        graphql_type: "Customer",
        query_builder: query_builder,
        record_query: record_query_stub,
        fragment: fragment,
        map_response_proc: map_response_proc,
        loader_instance: loader
      )

      query_string = collection_query.collection_graphql_query
      response_data = {
        "data" => {
          "customers" => {
            "nodes" => [
              { "id" => "gid://shopify/Customer/1" },
              { "id" => "gid://shopify/Customer/2" }
            ]
          }
        }
      }

      allow(loader).to receive(:perform_graphql_query).with(query_string, query: "", first: 250).and_return(response_data)

      result = collection_query.execute

      expect(result.length).to eq(2)
    end

    it "builds query string from conditions" do
      loader = mock_loader_instance

      query_builder = instance_double(ActiveShopifyGraphQL::RecordQuery)
      # record_query_stub is used instead
      fragment = instance_double(ActiveShopifyGraphQL::Fragment, to_s: "fragment OrderFragment on Order { id }", fragment_name: "OrderFragment")
      map_response_proc = ->(_response) { {} }
      collection_query = described_class.new(
        graphql_type: "Order",
        query_builder: query_builder,
        record_query: record_query_stub,
        fragment: fragment,
        map_response_proc: map_response_proc,
        loader_instance: loader
      )

      query_string = collection_query.collection_graphql_query
      response_data = { "data" => { "orders" => { "nodes" => [] } } }

      allow(loader).to receive(:perform_graphql_query).with(query_string, query: "status:open", first: 250).and_return(response_data)

      collection_query.execute({ status: "open" })

      expect(loader).to have_received(:perform_graphql_query).with(query_string, query: "status:open", first: 250)
    end

    it "accepts custom limit parameter" do
      loader = mock_loader_instance

      query_builder = instance_double(ActiveShopifyGraphQL::RecordQuery)
      # record_query_stub is used instead
      fragment = instance_double(ActiveShopifyGraphQL::Fragment, to_s: "fragment CustomerFragment on Customer { id }", fragment_name: "CustomerFragment")
      map_response_proc = ->(_response) { {} }
      collection_query = described_class.new(
        graphql_type: "Customer",
        query_builder: query_builder,
        record_query: record_query_stub,
        fragment: fragment,
        map_response_proc: map_response_proc,
        loader_instance: loader
      )

      query_string = collection_query.collection_graphql_query
      response_data = { "data" => { "customers" => { "nodes" => [] } } }

      allow(loader).to receive(:perform_graphql_query).with(query_string, query: "", first: 50).and_return(response_data)

      collection_query.execute({}, limit: 50)

      expect(loader).to have_received(:perform_graphql_query).with(query_string, query: "", first: 50)
    end

    it "returns empty array when no nodes found" do
      loader = mock_loader_instance

      query_builder = instance_double(ActiveShopifyGraphQL::RecordQuery)
      # record_query_stub is used instead
      fragment = instance_double(ActiveShopifyGraphQL::Fragment, to_s: "fragment CustomerFragment on Customer { id }", fragment_name: "CustomerFragment")
      map_response_proc = ->(_response) { {} }
      collection_query = described_class.new(
        graphql_type: "Customer",
        query_builder: query_builder,
        record_query: record_query_stub,
        fragment: fragment,
        map_response_proc: map_response_proc,
        loader_instance: loader
      )

      collection_query.collection_graphql_query
      response_data = { "data" => { "customers" => { "nodes" => [] } } }

      allow(loader).to receive(:perform_graphql_query).and_return(response_data)

      result = collection_query.execute

      expect(result).to eq([])
    end

    it "returns empty array when nodes is nil" do
      loader = mock_loader_instance

      query_builder = instance_double(ActiveShopifyGraphQL::RecordQuery)
      # record_query_stub is used instead
      fragment = instance_double(ActiveShopifyGraphQL::Fragment, to_s: "fragment CustomerFragment on Customer { id }", fragment_name: "CustomerFragment")
      map_response_proc = ->(_response) { {} }
      collection_query = described_class.new(
        graphql_type: "Customer",
        query_builder: query_builder,
        record_query: record_query_stub,
        fragment: fragment,
        map_response_proc: map_response_proc,
        loader_instance: loader
      )

      collection_query.collection_graphql_query
      response_data = { "data" => { "customers" => {} } }

      allow(loader).to receive(:perform_graphql_query).and_return(response_data)

      result = collection_query.execute

      expect(result).to eq([])
    end

    it "raises error on query validation warnings" do
      loader = mock_loader_instance

      query_builder = instance_double(ActiveShopifyGraphQL::RecordQuery)
      # record_query_stub is used instead
      fragment = instance_double(ActiveShopifyGraphQL::Fragment, to_s: "fragment CustomerFragment on Customer { id }", fragment_name: "CustomerFragment")
      map_response_proc = ->(_response) { {} }
      collection_query = described_class.new(
        graphql_type: "Customer",
        query_builder: query_builder,
        record_query: record_query_stub,
        fragment: fragment,
        map_response_proc: map_response_proc,
        loader_instance: loader
      )

      collection_query.collection_graphql_query
      response_data = {
        "data" => { "customers" => { "nodes" => [] } },
        "extensions" => {
          "search" => [
            {
              "warnings" => [
                { "field" => "invalid_field", "message" => "Unknown field" }
              ]
            }
          ]
        }
      }

      allow(loader).to receive(:perform_graphql_query).and_return(response_data)

      expect { collection_query.execute }.to raise_error(ArgumentError, /Shopify query validation failed/)
    end
  end

  describe "#collection_graphql_query" do
    it "builds collection query with plural query name" do
      query_builder = instance_double(ActiveShopifyGraphQL::RecordQuery)
      # record_query_stub is used instead
      fragment = instance_double(ActiveShopifyGraphQL::Fragment, to_s: "fragment CustomerFragment on Customer { id name }", fragment_name: "CustomerFragment")
      map_response_proc = ->(_response) { {} }
      collection_query = described_class.new(
        graphql_type: "Customer",
        query_builder: query_builder,
        record_query: record_query_stub,
        fragment: fragment,
        map_response_proc: map_response_proc,
        loader_instance: mock_loader_instance
      )

      result = collection_query.collection_graphql_query

      expect(result).to include("fragment CustomerFragment on Customer { id name }")
      expect(result).to include("query getCustomers($query: String, $first: Int!)")
      expect(result).to include("customers(query: $query, first: $first)")
      expect(result).to include("nodes")
      expect(result).to include("...CustomerFragment")
    end

    it "accepts optional model_type parameter" do
      query_builder = instance_double(ActiveShopifyGraphQL::RecordQuery)
      # record_query_stub is used instead
      fragment = instance_double(ActiveShopifyGraphQL::Fragment, to_s: "fragment OrderFragment on Order { id name }", fragment_name: "OrderFragment")
      map_response_proc = ->(_response) { {} }
      collection_query = described_class.new(
        graphql_type: "Customer",
        query_builder: query_builder,
        record_query: record_query_stub,
        fragment: fragment,
        map_response_proc: map_response_proc,
        loader_instance: mock_loader_instance
      )

      result = collection_query.collection_graphql_query("Order")

      expect(result).to include("query getOrders($query: String, $first: Int!)")
      expect(result).to include("orders(query: $query, first: $first)")
    end

    it "builds compact query when compact_queries is enabled" do
      ActiveShopifyGraphQL.configure do |config|
        config.compact_queries = true
      end

      query_builder = instance_double(ActiveShopifyGraphQL::RecordQuery)
      # record_query_stub is used instead
      fragment = instance_double(ActiveShopifyGraphQL::Fragment, to_s: "fragment CustomerFragment on Customer { id name }", fragment_name: "CustomerFragment")
      map_response_proc = ->(_response) { {} }
      collection_query = described_class.new(
        graphql_type: "Customer",
        query_builder: query_builder,
        record_query: record_query_stub,
        fragment: fragment,
        map_response_proc: map_response_proc,
        loader_instance: mock_loader_instance
      )

      result = collection_query.collection_graphql_query

      expect(result).not_to include("\n")
      expect(result).to eq("fragment CustomerFragment on Customer { id name } query getCustomers($query: String, $first: Int!) { customers(query: $query, first: $first) { nodes { ...CustomerFragment } } }")
    end
  end
end
