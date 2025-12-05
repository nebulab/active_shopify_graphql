# frozen_string_literal: true

RSpec.describe ActiveShopifyGraphQL::ConnectionLoader do
  describe "#initialize" do
    it "stores the query_builder" do
      query_builder = instance_double(ActiveShopifyGraphQL::ConnectionQuery)
      mapper_factory = -> { instance_double(ActiveShopifyGraphQL::ResponseMapper) }

      loader = described_class.new(
        connection_query: query_builder,
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        client_type: :admin_api,
        response_mapper_factory: mapper_factory
      )

      expect(loader.connection_query).to eq(query_builder)
    end

    it "stores the loader_class" do
      query_builder = instance_double(ActiveShopifyGraphQL::ConnectionQuery)
      mapper_factory = -> { instance_double(ActiveShopifyGraphQL::ResponseMapper) }

      loader = described_class.new(
        connection_query: query_builder,
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        client_type: :admin_api,
        response_mapper_factory: mapper_factory
      )

      expect(loader.loader_class).to eq(ActiveShopifyGraphQL::AdminApiLoader)
    end
  end

  describe "#load_records" do
    after do
      ActiveShopifyGraphQL.reset_configuration!
    end

    context "with root-level connection" do
      it "loads records using connection query" do
        mock_client = instance_double("GraphQLClient")
        ActiveShopifyGraphQL.configure do |config|
          config.admin_api_client = mock_client
        end

        query_builder = instance_double(ActiveShopifyGraphQL::ConnectionQuery)
        response_mapper = instance_double(ActiveShopifyGraphQL::ResponseMapper)
        mapper_factory = -> { response_mapper }

        loader = described_class.new(
          connection_query: query_builder,
          loader_class: ActiveShopifyGraphQL::AdminApiLoader,
          client_type: :admin_api,
          response_mapper_factory: mapper_factory
        )

        query_string = "query { orders(first: 10) { edges { node { id } } } }"
        response_data = { "data" => { "orders" => { "edges" => [] } } }
        expected_records = []

        allow(query_builder).to receive(:connection_graphql_query).with("orders", { first: 10 }, nil).and_return(query_string)
        allow(mock_client).to receive(:execute).with(query_string).and_return(response_data)
        allow(response_mapper).to receive(:map_connection_response_to_attributes).with(response_data, "orders", nil).and_return(expected_records)

        result = loader.load_records("orders", { first: 10 })

        expect(result).to eq(expected_records)
        expect(query_builder).to have_received(:connection_graphql_query).with("orders", { first: 10 }, nil)
        expect(response_mapper).to have_received(:map_connection_response_to_attributes).with(response_data, "orders", nil)
      end

      it "passes connection_config to query builder and mapper" do
        mock_client = instance_double("GraphQLClient")
        ActiveShopifyGraphQL.configure do |config|
          config.admin_api_client = mock_client
        end

        query_builder = instance_double(ActiveShopifyGraphQL::ConnectionQuery)
        response_mapper = instance_double(ActiveShopifyGraphQL::ResponseMapper)
        mapper_factory = -> { response_mapper }

        loader = described_class.new(
          connection_query: query_builder,
          loader_class: ActiveShopifyGraphQL::AdminApiLoader,
          client_type: :admin_api,
          response_mapper_factory: mapper_factory
        )

        connection_config = { type: :singular }
        query_string = "query { shop { id } }"
        response_data = { "data" => { "shop" => { "id" => "123" } } }

        allow(query_builder).to receive(:connection_graphql_query).and_return(query_string)
        allow(mock_client).to receive(:execute).and_return(response_data)
        allow(response_mapper).to receive(:map_connection_response_to_attributes).and_return(nil)

        loader.load_records("shop", {}, nil, connection_config)

        expect(query_builder).to have_received(:connection_graphql_query).with("shop", {}, connection_config)
        expect(response_mapper).to have_received(:map_connection_response_to_attributes).with(response_data, "shop", connection_config)
      end

      it "returns empty array when response is nil" do
        mock_client = instance_double("GraphQLClient")
        ActiveShopifyGraphQL.configure do |config|
          config.admin_api_client = mock_client
        end

        query_builder = instance_double(ActiveShopifyGraphQL::ConnectionQuery)
        mapper_factory = -> { instance_double(ActiveShopifyGraphQL::ResponseMapper) }

        loader = described_class.new(
          connection_query: query_builder,
          loader_class: ActiveShopifyGraphQL::AdminApiLoader,
          client_type: :admin_api,
          response_mapper_factory: mapper_factory
        )

        allow(query_builder).to receive(:connection_graphql_query).and_return("query {}")
        allow(mock_client).to receive(:execute).and_return(nil)

        result = loader.load_records("orders", { first: 10 })

        expect(result).to eq([])
      end
    end

    context "with nested connection" do
      it "loads records using nested connection query" do
        mock_client = instance_double("GraphQLClient")
        ActiveShopifyGraphQL.configure do |config|
          config.admin_api_client = mock_client
        end

        query_builder = instance_double(ActiveShopifyGraphQL::ConnectionQuery)
        response_mapper = instance_double(ActiveShopifyGraphQL::ResponseMapper)
        mapper_factory = -> { response_mapper }

        loader = described_class.new(
          connection_query: query_builder,
          loader_class: ActiveShopifyGraphQL::AdminApiLoader,
          client_type: :admin_api,
          response_mapper_factory: mapper_factory
        )

        parent_class = Class.new do
          attr_accessor :id

          def self.graphql_type_for_loader(_loader)
            "Customer"
          end

          def self.graphql_type
            "Customer"
          end
        end
        parent = parent_class.new
        parent.id = "gid://shopify/Customer/123"

        connection_config = { nested: true }
        query_string = "query($id: ID!) { customer(id: $id) { orders { edges { node { id } } } } }"
        response_data = { "data" => { "customer" => { "orders" => { "edges" => [] } } } }
        expected_records = []

        allow(query_builder).to receive(:nested_connection_graphql_query).with("orders", { first: 10 }, parent, connection_config).and_return(query_string)
        allow(mock_client).to receive(:execute).with(query_string, id: "gid://shopify/Customer/123").and_return(response_data)
        allow(response_mapper).to receive(:map_nested_connection_response_to_attributes).with(response_data, "orders", parent, connection_config).and_return(expected_records)

        result = loader.load_records("orders", { first: 10 }, parent, connection_config)

        expect(result).to eq(expected_records)
        expect(query_builder).to have_received(:nested_connection_graphql_query).with("orders", { first: 10 }, parent, connection_config)
        expect(response_mapper).to have_received(:map_nested_connection_response_to_attributes).with(response_data, "orders", parent, connection_config)
      end

      it "detects nested connection when parent responds to id" do
        mock_client = instance_double("GraphQLClient")
        ActiveShopifyGraphQL.configure do |config|
          config.admin_api_client = mock_client
        end

        query_builder = instance_double(ActiveShopifyGraphQL::ConnectionQuery)
        response_mapper = instance_double(ActiveShopifyGraphQL::ResponseMapper)
        mapper_factory = -> { response_mapper }

        loader = described_class.new(
          connection_query: query_builder,
          loader_class: ActiveShopifyGraphQL::AdminApiLoader,
          client_type: :admin_api,
          response_mapper_factory: mapper_factory
        )

        parent_class = Class.new do
          attr_accessor :id

          def self.graphql_type_for_loader(_loader)
            "Customer"
          end

          def self.graphql_type
            "Customer"
          end
        end
        parent = parent_class.new
        parent.id = "gid://shopify/Customer/456"

        allow(query_builder).to receive(:nested_connection_graphql_query).and_return("query {}")
        allow(mock_client).to receive(:execute).and_return({ "data" => {} })
        allow(response_mapper).to receive(:map_nested_connection_response_to_attributes).and_return([])

        loader.load_records("orders", {}, parent)

        expect(query_builder).to have_received(:nested_connection_graphql_query)
        expect(response_mapper).to have_received(:map_nested_connection_response_to_attributes)
      end

      it "normalizes numeric ID to GID format" do
        mock_client = instance_double("GraphQLClient")
        ActiveShopifyGraphQL.configure do |config|
          config.admin_api_client = mock_client
        end

        query_builder = instance_double(ActiveShopifyGraphQL::ConnectionQuery)
        response_mapper = instance_double(ActiveShopifyGraphQL::ResponseMapper)
        mapper_factory = -> { response_mapper }

        loader = described_class.new(
          connection_query: query_builder,
          loader_class: ActiveShopifyGraphQL::AdminApiLoader,
          client_type: :admin_api,
          response_mapper_factory: mapper_factory
        )

        parent_class = Class.new do
          attr_accessor :id

          def self.graphql_type_for_loader(_loader)
            "Customer"
          end

          def self.graphql_type
            "Customer"
          end
        end
        parent = parent_class.new
        parent.id = 789

        allow(query_builder).to receive(:nested_connection_graphql_query).and_return("query {}")
        allow(mock_client).to receive(:execute).with("query {}", id: "gid://shopify/Customer/789").and_return({ "data" => {} })
        allow(response_mapper).to receive(:map_nested_connection_response_to_attributes).and_return([])

        loader.load_records("orders", {}, parent)

        expect(mock_client).to have_received(:execute).with("query {}", id: "gid://shopify/Customer/789")
      end

      it "uses gid attribute if available on parent" do
        mock_client = instance_double("GraphQLClient")
        ActiveShopifyGraphQL.configure do |config|
          config.admin_api_client = mock_client
        end

        query_builder = instance_double(ActiveShopifyGraphQL::ConnectionQuery)
        response_mapper = instance_double(ActiveShopifyGraphQL::ResponseMapper)
        mapper_factory = -> { response_mapper }

        loader = described_class.new(
          connection_query: query_builder,
          loader_class: ActiveShopifyGraphQL::AdminApiLoader,
          client_type: :admin_api,
          response_mapper_factory: mapper_factory
        )

        parent_class = Class.new do
          attr_accessor :id, :gid

          def self.graphql_type_for_loader(_loader)
            "Customer"
          end

          def self.graphql_type
            "Customer"
          end
        end
        parent = parent_class.new
        parent.id = 999
        parent.gid = "gid://shopify/Customer/888"

        allow(query_builder).to receive(:nested_connection_graphql_query).and_return("query {}")
        allow(mock_client).to receive(:execute).with("query {}", id: "gid://shopify/Customer/888").and_return({ "data" => {} })
        allow(response_mapper).to receive(:map_nested_connection_response_to_attributes).and_return([])

        loader.load_records("orders", {}, parent)

        expect(mock_client).to have_received(:execute).with("query {}", id: "gid://shopify/Customer/888")
      end

      it "returns empty array when response is nil" do
        mock_client = instance_double("GraphQLClient")
        ActiveShopifyGraphQL.configure do |config|
          config.admin_api_client = mock_client
        end

        query_builder = instance_double(ActiveShopifyGraphQL::ConnectionQuery)
        mapper_factory = -> { instance_double(ActiveShopifyGraphQL::ResponseMapper) }

        loader = described_class.new(
          connection_query: query_builder,
          loader_class: ActiveShopifyGraphQL::AdminApiLoader,
          client_type: :admin_api,
          response_mapper_factory: mapper_factory
        )

        parent_class = Class.new do
          attr_accessor :id

          def self.graphql_type_for_loader(_loader)
            "Customer"
          end

          def self.graphql_type
            "Customer"
          end
        end
        parent = parent_class.new
        parent.id = "gid://shopify/Customer/123"

        allow(query_builder).to receive(:nested_connection_graphql_query).and_return("query {}")
        allow(mock_client).to receive(:execute).and_return(nil)

        result = loader.load_records("orders", {}, parent)

        expect(result).to eq([])
      end
    end
  end
end
