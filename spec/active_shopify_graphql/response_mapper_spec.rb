# frozen_string_literal: true

RSpec.describe ActiveShopifyGraphQL::ResponseMapper do
  def record_query_stub
    query_stub = instance_double(ActiveShopifyGraphQL::RecordQuery)
    allow(query_stub).to receive(:query_name, &:downcase)
    query_stub
  end

  describe "#initialize" do
    it "stores the graphql_type" do
      mapper = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: [],
        record_query: record_query_stub
      )

      expect(mapper.graphql_type).to eq("Customer")
    end

    it "stores the loader_class" do
      mapper = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: [],
        record_query: record_query_stub
      )

      expect(mapper.loader_class).to eq(ActiveShopifyGraphQL::AdminApiLoader)
    end

    it "stores the defined_attributes" do
      attributes = { id: { path: "id", type: :string } }
      mapper = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: attributes,
        model_class: Class.new,
        included_connections: [],
        record_query: record_query_stub
      )

      expect(mapper.defined_attributes).to eq(attributes)
    end

    it "stores the model_class" do
      model = Class.new
      mapper = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: {},
        model_class: model,
        included_connections: [],
        record_query: record_query_stub
      )

      expect(mapper.model_class).to eq(model)
    end

    it "stores the included_connections" do
      connections = [:orders]
      mapper = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: connections,
        record_query: record_query_stub
      )

      expect(mapper.included_connections).to eq(connections)
    end
  end

  describe "#map_response_from_attributes" do
    it "maps simple flat attributes from response" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        email: { path: "email", type: :string, null: true }
      }
      mapper = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: attributes,
        model_class: Class.new,
        included_connections: [],
        record_query: record_query_stub
      )

      response_data = {
        "data" => {
          "customer" => {
            "id" => "gid://shopify/Customer/123",
            "email" => "test@example.com"
          }
        }
      }

      result = mapper.map_response_from_attributes(response_data)

      expect(result).to eq({
                             id: "gid://shopify/Customer/123",
                             email: "test@example.com"
                           })
    end

    it "maps nested attributes using dotted paths" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        amount: { path: "totalPriceSet.shopMoney.amount", type: :string, null: true }
      }
      mapper = described_class.new(
        graphql_type: "Order",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: attributes,
        model_class: Class.new,
        included_connections: [],
        record_query: record_query_stub
      )

      response_data = {
        "data" => {
          "order" => {
            "id" => "gid://shopify/Order/456",
            "totalPriceSet" => {
              "shopMoney" => {
                "amount" => "99.99"
              }
            }
          }
        }
      }

      result = mapper.map_response_from_attributes(response_data)

      expect(result).to eq({
                             id: "gid://shopify/Order/456",
                             amount: "99.99"
                           })
    end

    it "applies type coercion" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        count: { path: "orderCount", type: :integer, null: true },
        verified: { path: "verified", type: :boolean, null: true }
      }
      mapper = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: attributes,
        model_class: Class.new,
        included_connections: [],
        record_query: record_query_stub
      )

      response_data = {
        "data" => {
          "customer" => {
            "id" => "gid://shopify/Customer/123",
            "orderCount" => "42",
            "verified" => "true"
          }
        }
      }

      result = mapper.map_response_from_attributes(response_data)

      expect(result[:count]).to eq(42)
      expect(result[:count]).to be_a(Integer)
      expect(result[:verified]).to be true
      expect(result[:verified]).to be_a(TrueClass)
    end

    it "applies transform functions" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        tags: { path: "tags", type: :string, null: true, transform: ->(v) { v.is_a?(Array) ? v : [] } }
      }
      mapper = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: attributes,
        model_class: Class.new,
        included_connections: [],
        record_query: record_query_stub
      )

      response_data = {
        "data" => {
          "customer" => {
            "id" => "gid://shopify/Customer/123",
            "tags" => %w[vip loyal]
          }
        }
      }

      result = mapper.map_response_from_attributes(response_data)

      expect(result[:tags]).to eq(%w[vip loyal])
    end

    it "uses default values when field is missing" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        status: { path: "status", type: :string, null: true, default: "pending" }
      }
      mapper = described_class.new(
        graphql_type: "Order",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: attributes,
        model_class: Class.new,
        included_connections: [],
        record_query: record_query_stub
      )

      response_data = {
        "data" => {
          "order" => {
            "id" => "gid://shopify/Order/456"
          }
        }
      }

      result = mapper.map_response_from_attributes(response_data)

      expect(result[:status]).to eq("pending")
    end

    it "preserves arrays regardless of type specification" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        tags: { path: "tags", type: :string, null: true }
      }
      mapper = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: attributes,
        model_class: Class.new,
        included_connections: [],
        record_query: record_query_stub
      )

      response_data = {
        "data" => {
          "customer" => {
            "id" => "gid://shopify/Customer/123",
            "tags" => %w[tag1 tag2]
          }
        }
      }

      result = mapper.map_response_from_attributes(response_data)

      expect(result[:tags]).to eq(%w[tag1 tag2])
      expect(result[:tags]).to be_a(Array)
    end

    it "raises error when non-nullable field is nil" do
      attributes = {
        id: { path: "id", type: :string, null: false }
      }
      mapper = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: attributes,
        model_class: Class.new,
        included_connections: [],
        record_query: record_query_stub
      )

      response_data = {
        "data" => {
          "customer" => {
            "id" => nil
          }
        }
      }

      expect { mapper.map_response_from_attributes(response_data) }.to raise_error(ArgumentError, /cannot be null/)
    end

    it "returns empty hash when root data is nil" do
      attributes = {
        id: { path: "id", type: :string, null: false }
      }
      mapper = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: attributes,
        model_class: Class.new,
        included_connections: [],
        record_query: record_query_stub
      )

      response_data = { "data" => { "customer" => nil } }

      result = mapper.map_response_from_attributes(response_data)

      expect(result).to eq({})
    end
  end

  describe "#coerce_value" do
    it "coerces string type" do
      mapper = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: [],
        record_query: record_query_stub
      )

      result = mapper.coerce_value(123, :string, :test_attr, "path")

      expect(result).to eq("123")
      expect(result).to be_a(String)
    end

    it "coerces integer type" do
      mapper = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: [],
        record_query: record_query_stub
      )

      result = mapper.coerce_value("42", :integer, :test_attr, "path")

      expect(result).to eq(42)
      expect(result).to be_a(Integer)
    end

    it "coerces float type" do
      mapper = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: [],
        record_query: record_query_stub
      )

      result = mapper.coerce_value("3.14", :float, :test_attr, "path")

      expect(result).to eq(3.14)
      expect(result).to be_a(Float)
    end

    it "coerces boolean type" do
      mapper = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: [],
        record_query: record_query_stub
      )

      result_true = mapper.coerce_value("true", :boolean, :test_attr, "path")
      result_false = mapper.coerce_value("false", :boolean, :test_attr, "path")

      expect(result_true).to be true
      expect(result_false).to be false
    end

    it "preserves arrays without coercion" do
      mapper = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: [],
        record_query: record_query_stub
      )

      array_value = %w[a b c]
      result = mapper.coerce_value(array_value, :string, :test_attr, "path")

      expect(result).to eq(%w[a b c])
      expect(result).to be_a(Array)
    end

    it "returns 0 for invalid integer conversion" do
      mapper = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: [],
        record_query: record_query_stub
      )

      result = mapper.coerce_value("not_a_number", :integer, :count, "orderCount")

      expect(result).to eq(0)
    end

    it "returns value as-is for unknown type" do
      mapper = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: [],
        record_query: record_query_stub
      )

      value = { "custom" => "data" }
      result = mapper.coerce_value(value, :json, :test_attr, "path")

      expect(result).to eq(value)
    end
  end

  describe "#extract_connection_data" do
    it "returns empty hash when no connections included" do
      mapper = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: [],
        record_query: record_query_stub
      )

      response_data = { "data" => { "customer" => { "id" => "123" } } }

      result = mapper.extract_connection_data(response_data)

      expect(result).to eq({})
    end

    it "returns empty hash when model doesn't support connections" do
      model = Class.new
      mapper = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: {},
        model_class: model,
        included_connections: [:orders],
        record_query: record_query_stub
      )

      response_data = { "data" => { "customer" => { "id" => "123" } } }

      result = mapper.extract_connection_data(response_data)

      expect(result).to eq({})
    end

    it "returns empty hash when root data is nil" do
      mapper = described_class.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: {},
        model_class: Class.new,
        included_connections: [],
        record_query: record_query_stub
      )

      response_data = { "data" => { "customer" => nil } }

      result = mapper.extract_connection_data(response_data)

      expect(result).to eq({})
    end
  end

  describe "#map_connection_response_to_attributes" do
    it "maps connection response with edges" do
      attributes = { id: { path: "id", type: :string, null: false } }
      model_class = Class.new do
        attr_accessor :id

        def initialize(attrs = {})
          @id = attrs[:id]
        end

        def self.respond_to?(method, _include_private = false)
          method == :attributes_for_loader
        end

        def self.attributes_for_loader(_loader)
          { id: { path: "id", type: :string, null: false } }
        end
      end

      mapper = described_class.new(
        graphql_type: "Order",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: attributes,
        model_class: model_class,
        included_connections: [],
        record_query: record_query_stub
      )

      response_data = {
        "data" => {
          "orders" => {
            "edges" => [
              { "node" => { "id" => "gid://shopify/Order/1" } },
              { "node" => { "id" => "gid://shopify/Order/2" } }
            ]
          }
        }
      }

      result = mapper.map_connection_response_to_attributes(response_data, "orders")

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result.first).to be_a(model_class)
      expect(result.first.id).to eq("gid://shopify/Order/1")
    end

    it "maps singular connection response" do
      attributes = { id: { path: "id", type: :string, null: false } }
      model_class = Class.new do
        attr_accessor :id

        def initialize(attrs = {})
          @id = attrs[:id]
        end

        def self.respond_to?(method, _include_private = false)
          method == :attributes_for_loader
        end

        def self.attributes_for_loader(_loader)
          { id: { path: "id", type: :string, null: false } }
        end
      end

      mapper = described_class.new(
        graphql_type: "Shop",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: attributes,
        model_class: model_class,
        included_connections: [],
        record_query: record_query_stub
      )

      response_data = {
        "data" => {
          "shop" => { "id" => "gid://shopify/Shop/1" }
        }
      }

      result = mapper.map_connection_response_to_attributes(response_data, "shop", { type: :singular })

      expect(result).to be_a(model_class)
      expect(result.id).to eq("gid://shopify/Shop/1")
    end

    it "returns empty array when edges is nil" do
      attributes = { id: { path: "id", type: :string, null: false } }
      mapper = described_class.new(
        graphql_type: "Order",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: attributes,
        model_class: Class.new,
        included_connections: [],
        record_query: record_query_stub
      )

      response_data = { "data" => { "orders" => {} } }

      result = mapper.map_connection_response_to_attributes(response_data, "orders")

      expect(result).to eq([])
    end

    it "returns nil when singular node is nil" do
      attributes = { id: { path: "id", type: :string, null: false } }
      mapper = described_class.new(
        graphql_type: "Shop",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: attributes,
        model_class: Class.new,
        included_connections: [],
        record_query: record_query_stub
      )

      response_data = { "data" => { "shop" => nil } }

      result = mapper.map_connection_response_to_attributes(response_data, "shop", { type: :singular })

      expect(result).to be_nil
    end

    it "filters out nil nodes from edges" do
      attributes = { id: { path: "id", type: :string, null: false } }
      model_class = Class.new do
        attr_accessor :id

        def initialize(attrs = {})
          @id = attrs[:id]
        end

        def self.respond_to?(method, _include_private = false)
          method == :attributes_for_loader
        end

        def self.attributes_for_loader(_loader)
          { id: { path: "id", type: :string, null: false } }
        end
      end

      mapper = described_class.new(
        graphql_type: "Order",
        loader_class: ActiveShopifyGraphQL::AdminApiLoader,
        defined_attributes: attributes,
        model_class: model_class,
        included_connections: [],
        record_query: record_query_stub
      )

      response_data = {
        "data" => {
          "orders" => {
            "edges" => [
              { "node" => { "id" => "gid://shopify/Order/1" } },
              { "node" => nil },
              { "node" => { "id" => "gid://shopify/Order/3" } }
            ]
          }
        }
      }

      result = mapper.map_connection_response_to_attributes(response_data, "orders")

      expect(result.length).to eq(2)
      expect(result.map(&:id)).to eq(["gid://shopify/Order/1", "gid://shopify/Order/3"])
    end
  end
end
