# frozen_string_literal: true

RSpec.describe ActiveShopifyGraphQL::ConnectionLoader do
  def mock_loader_instance
    loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
    allow(loader).to receive(:perform_graphql_query)
    loader
  end

  def mock_model_class(type_name = "TestModel")
    Class.new do
      define_singleton_method(:graphql_type_for_loader) { |_loader| type_name }
      define_singleton_method(:graphql_type) { type_name }
    end
  end

  describe "#load_records" do
    after do
      ActiveShopifyGraphQL.reset_configuration!
    end

    context "with root-level connection" do
      it "loads records using QueryTree to build the query" do
        loader_instance = mock_loader_instance
        response_mapper = instance_double(ActiveShopifyGraphQL::ResponseMapper)
        mapper_factory = -> { response_mapper }

        loader = described_class.new(
          graphql_type: "Order",
          loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
          defined_attributes: { id: { path: 'id', type: :string } },
          model_class: mock_model_class("Order"),
          included_connections: [],
          loader_instance: loader_instance,
          response_mapper_factory: mapper_factory
        )

        response_data = { "data" => { "orders" => { "edges" => [] } } }
        expected_records = []

        allow(loader_instance).to receive(:perform_graphql_query).and_return(response_data)
        allow(response_mapper).to receive(:map_connection_response_to_attributes).with(response_data, "orders", nil).and_return(expected_records)

        result = loader.load_records("orders", { first: 10 })

        expect(result).to eq(expected_records)
        # Verify that perform_graphql_query was called with a query string
        expect(loader_instance).to have_received(:perform_graphql_query) do |query, **vars|
          expect(query).to be_a(String)
          expect(query).to include("orders")
          expect(vars).to eq({})
        end
        expect(response_mapper).to have_received(:map_connection_response_to_attributes).with(response_data, "orders", nil)
      end

      it "passes connection_config to the response mapper" do
        loader_instance = mock_loader_instance
        response_mapper = instance_double(ActiveShopifyGraphQL::ResponseMapper)
        mapper_factory = -> { response_mapper }

        loader = described_class.new(
          graphql_type: "Shop",
          loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
          defined_attributes: { id: { path: 'id', type: :string } },
          model_class: mock_model_class("Shop"),
          included_connections: [],
          loader_instance: loader_instance,
          response_mapper_factory: mapper_factory
        )

        connection_config = { type: :singular }
        response_data = { "data" => { "shop" => { "id" => "123" } } }

        allow(loader_instance).to receive(:perform_graphql_query).and_return(response_data)
        allow(response_mapper).to receive(:map_connection_response_to_attributes).and_return(nil)

        loader.load_records("shop", {}, nil, connection_config)

        # Verify query was built with singular connection type
        expect(loader_instance).to have_received(:perform_graphql_query) do |query, **vars|
          expect(query).to be_a(String)
          expect(query).to include("shop")
          expect(vars).to eq({})
        end
        expect(response_mapper).to have_received(:map_connection_response_to_attributes).with(response_data, "shop", connection_config)
      end

      it "returns empty array when response is nil" do
        loader_instance = mock_loader_instance
        mapper_factory = -> { instance_double(ActiveShopifyGraphQL::ResponseMapper) }

        loader = described_class.new(
          graphql_type: "Order",
          loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
          defined_attributes: { id: { path: 'id', type: :string } },
          model_class: mock_model_class("Order"),
          included_connections: [],
          loader_instance: loader_instance,
          response_mapper_factory: mapper_factory
        )

        allow(loader_instance).to receive(:perform_graphql_query).and_return(nil)

        result = loader.load_records("orders", { first: 10 })

        expect(result).to eq([])
      end
    end

    context "with nested connection" do
      it "loads records using QueryTree with parent query" do
        loader_instance = mock_loader_instance
        response_mapper = instance_double(ActiveShopifyGraphQL::ResponseMapper)
        mapper_factory = -> { response_mapper }

        loader = described_class.new(
          graphql_type: "Order",
          loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
          defined_attributes: { id: { path: 'id', type: :string } },
          model_class: mock_model_class("Order"),
          included_connections: [],
          loader_instance: loader_instance,
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
        response_data = { "data" => { "customer" => { "orders" => { "edges" => [] } } } }
        expected_records = []

        allow(loader_instance).to receive(:perform_graphql_query).and_return(response_data)
        allow(response_mapper).to receive(:map_nested_connection_response_to_attributes).with(response_data, "orders", parent, connection_config).and_return(expected_records)

        result = loader.load_records("orders", { first: 10 }, parent, connection_config)

        expect(result).to eq(expected_records)
        # Verify that perform_graphql_query was called with query string and parent ID
        expect(loader_instance).to have_received(:perform_graphql_query) do |query, **vars|
          expect(query).to be_a(String)
          expect(query).to include("customer")
          expect(query).to include("orders")
          expect(query).to include("$id")
          expect(vars).to eq({ id: "gid://shopify/Customer/123" })
        end
        expect(response_mapper).to have_received(:map_nested_connection_response_to_attributes).with(response_data, "orders", parent, connection_config)
      end

      it "detects nested connection when parent responds to id" do
        loader_instance = mock_loader_instance
        response_mapper = instance_double(ActiveShopifyGraphQL::ResponseMapper)
        mapper_factory = -> { response_mapper }

        loader = described_class.new(
          graphql_type: "Order",
          loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
          defined_attributes: { id: { path: 'id', type: :string } },
          model_class: mock_model_class("Order"),
          included_connections: [],
          loader_instance: loader_instance,
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

        allow(loader_instance).to receive(:perform_graphql_query).and_return({ "data" => {} })
        allow(response_mapper).to receive(:map_nested_connection_response_to_attributes).and_return([])

        loader.load_records("orders", {}, parent)

        # Verify nested query was built (with parent ID variable)
        expect(loader_instance).to have_received(:perform_graphql_query) do |query, **vars|
          expect(query).to be_a(String)
          expect(vars).to eq({ id: "gid://shopify/Customer/456" })
        end
        expect(response_mapper).to have_received(:map_nested_connection_response_to_attributes)
      end

      it "normalizes numeric ID to GID format" do
        loader_instance = mock_loader_instance
        response_mapper = instance_double(ActiveShopifyGraphQL::ResponseMapper)
        mapper_factory = -> { response_mapper }

        loader = described_class.new(
          graphql_type: "Order",
          loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
          defined_attributes: { id: { path: 'id', type: :string } },
          model_class: mock_model_class("Order"),
          included_connections: [],
          loader_instance: loader_instance,
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

        allow(loader_instance).to receive(:perform_graphql_query).and_return({ "data" => {} })
        allow(response_mapper).to receive(:map_nested_connection_response_to_attributes).and_return([])

        loader.load_records("orders", {}, parent)

        # Verify that the numeric ID was normalized to GID format
        expect(loader_instance).to have_received(:perform_graphql_query) do |_query, **vars|
          expect(vars[:id]).to eq("gid://shopify/Customer/789")
        end
      end

      it "uses gid attribute if available on parent" do
        loader_instance = mock_loader_instance
        response_mapper = instance_double(ActiveShopifyGraphQL::ResponseMapper)
        mapper_factory = -> { response_mapper }

        loader = described_class.new(
          graphql_type: "Order",
          loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
          defined_attributes: { id: { path: 'id', type: :string } },
          model_class: mock_model_class("Order"),
          included_connections: [],
          loader_instance: loader_instance,
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

        allow(loader_instance).to receive(:perform_graphql_query).and_return({ "data" => {} })
        allow(response_mapper).to receive(:map_nested_connection_response_to_attributes).and_return([])

        loader.load_records("orders", {}, parent)

        # Verify that the gid attribute was used instead of id
        expect(loader_instance).to have_received(:perform_graphql_query) do |_query, **vars|
          expect(vars[:id]).to eq("gid://shopify/Customer/888")
        end
      end

      it "returns empty array when response is nil" do
        loader_instance = mock_loader_instance
        mapper_factory = -> { instance_double(ActiveShopifyGraphQL::ResponseMapper) }

        loader = described_class.new(
          graphql_type: "Order",
          loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
          defined_attributes: { id: { path: 'id', type: :string } },
          model_class: mock_model_class("Order"),
          included_connections: [],
          loader_instance: loader_instance,
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

        allow(loader_instance).to receive(:perform_graphql_query).and_return(nil)

        result = loader.load_records("orders", {}, parent)

        expect(result).to eq([])
      end
    end
  end
end
