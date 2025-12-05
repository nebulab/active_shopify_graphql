# frozen_string_literal: true

RSpec.describe ActiveShopifyGraphQL::CollectionQuery do
  after do
    ActiveShopifyGraphQL.reset_configuration!
  end

  describe "#initialize" do
    it "stores the graphql_type" do
      query_builder = instance_double(ActiveShopifyGraphQL::Query)
      query_name_proc = ->(type) { type.downcase }
      map_response_proc = ->(_response) { {} }

      collection_query = described_class.new(
        graphql_type: "Customer",
        query_builder: query_builder,
        query_name_proc: query_name_proc,
        map_response_proc: map_response_proc,
        client_type: :admin_api
      )

      expect(collection_query.graphql_type).to eq("Customer")
    end
  end

  describe "#execute" do
    it "executes collection query and returns mapped results" do
      mock_client = instance_double("GraphQLClient")
      ActiveShopifyGraphQL.configure do |config|
        config.admin_api_client = mock_client
      end

      query_builder = instance_double(ActiveShopifyGraphQL::Query)
      query_name_proc = ->(type) { type.downcase }
      map_response_proc = ->(response) { response.dig("data", "customer") }

      collection_query = described_class.new(
        graphql_type: "Customer",
        query_builder: query_builder,
        query_name_proc: query_name_proc,
        map_response_proc: map_response_proc,
        client_type: :admin_api
      )

      query_string = "query { customers { nodes { id } } }"
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

      allow(query_builder).to receive(:collection_graphql_query).with("Customer").and_return(query_string)
      allow(mock_client).to receive(:execute).with(query_string, query: "", first: 250).and_return(response_data)

      result = collection_query.execute

      expect(result.length).to eq(2)
      expect(query_builder).to have_received(:collection_graphql_query).with("Customer")
    end

    it "builds query string from conditions" do
      mock_client = instance_double("GraphQLClient")
      ActiveShopifyGraphQL.configure do |config|
        config.admin_api_client = mock_client
      end

      query_builder = instance_double(ActiveShopifyGraphQL::Query)
      query_name_proc = ->(type) { type.downcase }
      map_response_proc = ->(_response) { {} }

      collection_query = described_class.new(
        graphql_type: "Order",
        query_builder: query_builder,
        query_name_proc: query_name_proc,
        map_response_proc: map_response_proc,
        client_type: :admin_api
      )

      query_string = "query { orders { nodes { id } } }"
      response_data = { "data" => { "orders" => { "nodes" => [] } } }

      allow(query_builder).to receive(:collection_graphql_query).and_return(query_string)
      allow(mock_client).to receive(:execute).with(query_string, query: "status:open", first: 250).and_return(response_data)

      collection_query.execute({ status: "open" })

      expect(mock_client).to have_received(:execute).with(query_string, query: "status:open", first: 250)
    end

    it "accepts custom limit parameter" do
      mock_client = instance_double("GraphQLClient")
      ActiveShopifyGraphQL.configure do |config|
        config.admin_api_client = mock_client
      end

      query_builder = instance_double(ActiveShopifyGraphQL::Query)
      query_name_proc = ->(type) { type.downcase }
      map_response_proc = ->(_response) { {} }

      collection_query = described_class.new(
        graphql_type: "Customer",
        query_builder: query_builder,
        query_name_proc: query_name_proc,
        map_response_proc: map_response_proc,
        client_type: :admin_api
      )

      query_string = "query { customers { nodes { id } } }"
      response_data = { "data" => { "customers" => { "nodes" => [] } } }

      allow(query_builder).to receive(:collection_graphql_query).and_return(query_string)
      allow(mock_client).to receive(:execute).with(query_string, query: "", first: 50).and_return(response_data)

      collection_query.execute({}, limit: 50)

      expect(mock_client).to have_received(:execute).with(query_string, query: "", first: 50)
    end

    it "returns empty array when no nodes found" do
      mock_client = instance_double("GraphQLClient")
      ActiveShopifyGraphQL.configure do |config|
        config.admin_api_client = mock_client
      end

      query_builder = instance_double(ActiveShopifyGraphQL::Query)
      query_name_proc = ->(type) { type.downcase }
      map_response_proc = ->(_response) { {} }

      collection_query = described_class.new(
        graphql_type: "Customer",
        query_builder: query_builder,
        query_name_proc: query_name_proc,
        map_response_proc: map_response_proc,
        client_type: :admin_api
      )

      query_string = "query { customers { nodes { id } } }"
      response_data = { "data" => { "customers" => { "nodes" => [] } } }

      allow(query_builder).to receive(:collection_graphql_query).and_return(query_string)
      allow(mock_client).to receive(:execute).and_return(response_data)

      result = collection_query.execute

      expect(result).to eq([])
    end

    it "returns empty array when nodes is nil" do
      mock_client = instance_double("GraphQLClient")
      ActiveShopifyGraphQL.configure do |config|
        config.admin_api_client = mock_client
      end

      query_builder = instance_double(ActiveShopifyGraphQL::Query)
      query_name_proc = ->(type) { type.downcase }
      map_response_proc = ->(_response) { {} }

      collection_query = described_class.new(
        graphql_type: "Customer",
        query_builder: query_builder,
        query_name_proc: query_name_proc,
        map_response_proc: map_response_proc,
        client_type: :admin_api
      )

      query_string = "query { customers { nodes { id } } }"
      response_data = { "data" => { "customers" => {} } }

      allow(query_builder).to receive(:collection_graphql_query).and_return(query_string)
      allow(mock_client).to receive(:execute).and_return(response_data)

      result = collection_query.execute

      expect(result).to eq([])
    end

    it "raises error on query validation warnings" do
      mock_client = instance_double("GraphQLClient")
      ActiveShopifyGraphQL.configure do |config|
        config.admin_api_client = mock_client
      end

      query_builder = instance_double(ActiveShopifyGraphQL::Query)
      query_name_proc = ->(type) { type.downcase }
      map_response_proc = ->(_response) { {} }

      collection_query = described_class.new(
        graphql_type: "Customer",
        query_builder: query_builder,
        query_name_proc: query_name_proc,
        map_response_proc: map_response_proc,
        client_type: :admin_api
      )

      query_string = "query { customers { nodes { id } } }"
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

      allow(query_builder).to receive(:collection_graphql_query).and_return(query_string)
      allow(mock_client).to receive(:execute).and_return(response_data)

      expect { collection_query.execute }.to raise_error(ArgumentError, /Shopify query validation failed/)
    end
  end

  describe "query string building" do
    it "formats string conditions" do
      query_builder = instance_double(ActiveShopifyGraphQL::Query)
      query_name_proc = ->(type) { type.downcase }
      map_response_proc = ->(_response) { {} }

      collection_query = described_class.new(
        graphql_type: "Order",
        query_builder: query_builder,
        query_name_proc: query_name_proc,
        map_response_proc: map_response_proc,
        client_type: :admin_api
      )

      query_string = collection_query.send(:build_query_string, { status: "open" })

      expect(query_string).to eq("status:open")
    end

    it "formats numeric conditions" do
      query_builder = instance_double(ActiveShopifyGraphQL::Query)
      query_name_proc = ->(type) { type.downcase }
      map_response_proc = ->(_response) { {} }

      collection_query = described_class.new(
        graphql_type: "Order",
        query_builder: query_builder,
        query_name_proc: query_name_proc,
        map_response_proc: map_response_proc,
        client_type: :admin_api
      )

      query_string = collection_query.send(:build_query_string, { total_price: 100 })

      expect(query_string).to eq("total_price:100")
    end

    it "formats boolean conditions" do
      query_builder = instance_double(ActiveShopifyGraphQL::Query)
      query_name_proc = ->(type) { type.downcase }
      map_response_proc = ->(_response) { {} }

      collection_query = described_class.new(
        graphql_type: "Product",
        query_builder: query_builder,
        query_name_proc: query_name_proc,
        map_response_proc: map_response_proc,
        client_type: :admin_api
      )

      query_string = collection_query.send(:build_query_string, { published: true })

      expect(query_string).to eq("published:true")
    end

    it "quotes multi-word string values" do
      query_builder = instance_double(ActiveShopifyGraphQL::Query)
      query_name_proc = ->(type) { type.downcase }
      map_response_proc = ->(_response) { {} }

      collection_query = described_class.new(
        graphql_type: "Customer",
        query_builder: query_builder,
        query_name_proc: query_name_proc,
        map_response_proc: map_response_proc,
        client_type: :admin_api
      )

      query_string = collection_query.send(:build_query_string, { name: "John Doe" })

      expect(query_string).to eq('name:"John Doe"')
    end

    it "escapes quotes in string values" do
      query_builder = instance_double(ActiveShopifyGraphQL::Query)
      query_name_proc = ->(type) { type.downcase }
      map_response_proc = ->(_response) { {} }

      collection_query = described_class.new(
        graphql_type: "Product",
        query_builder: query_builder,
        query_name_proc: query_name_proc,
        map_response_proc: map_response_proc,
        client_type: :admin_api
      )

      query_string = collection_query.send(:build_query_string, { title: 'Test "Product"' })

      expect(query_string).to eq('title:"Test \\"Product\\""')
    end

    it "formats range conditions with gte" do
      query_builder = instance_double(ActiveShopifyGraphQL::Query)
      query_name_proc = ->(type) { type.downcase }
      map_response_proc = ->(_response) { {} }

      collection_query = described_class.new(
        graphql_type: "Order",
        query_builder: query_builder,
        query_name_proc: query_name_proc,
        map_response_proc: map_response_proc,
        client_type: :admin_api
      )

      query_string = collection_query.send(:build_query_string, { created_at: { gte: "2024-01-01" } })

      expect(query_string).to eq("created_at:>=2024-01-01")
    end

    it "formats range conditions with multiple operators" do
      query_builder = instance_double(ActiveShopifyGraphQL::Query)
      query_name_proc = ->(type) { type.downcase }
      map_response_proc = ->(_response) { {} }

      collection_query = described_class.new(
        graphql_type: "Order",
        query_builder: query_builder,
        query_name_proc: query_name_proc,
        map_response_proc: map_response_proc,
        client_type: :admin_api
      )

      query_string = collection_query.send(:build_query_string, { created_at: { gte: "2024-01-01", lte: "2024-12-31" } })

      expect(query_string).to include("created_at:>=2024-01-01")
      expect(query_string).to include("created_at:<=2024-12-31")
    end

    it "supports symbol range operators" do
      query_builder = instance_double(ActiveShopifyGraphQL::Query)
      query_name_proc = ->(type) { type.downcase }
      map_response_proc = ->(_response) { {} }

      collection_query = described_class.new(
        graphql_type: "Order",
        query_builder: query_builder,
        query_name_proc: query_name_proc,
        map_response_proc: map_response_proc,
        client_type: :admin_api
      )

      query_string = collection_query.send(:build_query_string, { created_at: { '>': "2024-01-01" } })

      expect(query_string).to eq("created_at:>2024-01-01")
    end

    it "combines multiple conditions with AND" do
      query_builder = instance_double(ActiveShopifyGraphQL::Query)
      query_name_proc = ->(type) { type.downcase }
      map_response_proc = ->(_response) { {} }

      collection_query = described_class.new(
        graphql_type: "Order",
        query_builder: query_builder,
        query_name_proc: query_name_proc,
        map_response_proc: map_response_proc,
        client_type: :admin_api
      )

      query_string = collection_query.send(:build_query_string, { status: "open", fulfillment_status: "unfulfilled" })

      expect(query_string).to include("status:open")
      expect(query_string).to include("fulfillment_status:unfulfilled")
      expect(query_string).to include(" AND ")
    end

    it "returns empty string for empty conditions" do
      query_builder = instance_double(ActiveShopifyGraphQL::Query)
      query_name_proc = ->(type) { type.downcase }
      map_response_proc = ->(_response) { {} }

      collection_query = described_class.new(
        graphql_type: "Order",
        query_builder: query_builder,
        query_name_proc: query_name_proc,
        map_response_proc: map_response_proc,
        client_type: :admin_api
      )

      query_string = collection_query.send(:build_query_string, {})

      expect(query_string).to eq("")
    end

    it "raises error for unsupported range operators" do
      query_builder = instance_double(ActiveShopifyGraphQL::Query)
      query_name_proc = ->(type) { type.downcase }
      map_response_proc = ->(_response) { {} }

      collection_query = described_class.new(
        graphql_type: "Order",
        query_builder: query_builder,
        query_name_proc: query_name_proc,
        map_response_proc: map_response_proc,
        client_type: :admin_api
      )

      expect do
        collection_query.send(:build_query_string, { created_at: { invalid: "2024-01-01" } })
      end.to raise_error(ArgumentError, /Unsupported range operator/)
    end
  end
end
