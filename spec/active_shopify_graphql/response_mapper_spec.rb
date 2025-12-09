# frozen_string_literal: true

RSpec.describe ActiveShopifyGraphQL::ResponseMapper do
  # Helper to create a context for tests
  def build_context(graphql_type: "Customer", attributes: {}, model_class: nil, included_connections: [])
    model_class ||= Class.new do
      def self.connections
        {}
      end
    end

    ActiveShopifyGraphQL::LoaderContext.new(
      graphql_type: graphql_type,
      loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
      defined_attributes: attributes,
      model_class: model_class,
      included_connections: included_connections
    )
  end

  describe "#map_response" do
    it "maps simple flat attributes from response" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        email: { path: "email", type: :string, null: true }
      }
      context = build_context(attributes: attributes)
      mapper = described_class.new(context)

      response_data = {
        "data" => {
          "customer" => {
            "id" => "gid://shopify/Customer/123",
            "email" => "test@example.com"
          }
        }
      }

      result = mapper.map_response(response_data)

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
      context = build_context(graphql_type: "Order", attributes: attributes)
      mapper = described_class.new(context)

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

      result = mapper.map_response(response_data)

      expect(result).to eq({
                             id: "gid://shopify/Order/456",
                             amount: "99.99"
                           })
    end

    it "applies type coercion" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        count: { path: "orderCount", type: :integer, null: true },
        active: { path: "active", type: :boolean, null: true }
      }
      context = build_context(attributes: attributes)
      mapper = described_class.new(context)

      response_data = {
        "data" => {
          "customer" => {
            "id" => "123",
            "orderCount" => "42",
            "active" => "true"
          }
        }
      }

      result = mapper.map_response(response_data)

      expect(result[:id]).to eq("123")
      expect(result[:count]).to eq(42)
      expect(result[:active]).to be true
    end

    it "applies transform functions" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        tags: { path: "tags", type: :string, null: true, transform: ->(v) { v&.join(", ") } }
      }
      context = build_context(attributes: attributes)
      mapper = described_class.new(context)

      response_data = {
        "data" => {
          "customer" => {
            "id" => "123",
            "tags" => %w[vip premium]
          }
        }
      }

      result = mapper.map_response(response_data)

      expect(result[:tags]).to eq("vip, premium")
    end

    it "uses default values when field is missing" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        status: { path: "status", type: :string, null: true, default: "pending" }
      }
      context = build_context(attributes: attributes)
      mapper = described_class.new(context)

      response_data = {
        "data" => {
          "customer" => {
            "id" => "123",
            "status" => nil
          }
        }
      }

      result = mapper.map_response(response_data)

      expect(result[:status]).to eq("pending")
    end

    it "preserves arrays regardless of type specification" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        tags: { path: "tags", type: :string, null: true }
      }
      context = build_context(attributes: attributes)
      mapper = described_class.new(context)

      response_data = {
        "data" => {
          "customer" => {
            "id" => "123",
            "tags" => %w[tag1 tag2 tag3]
          }
        }
      }

      result = mapper.map_response(response_data)

      expect(result[:tags]).to eq(%w[tag1 tag2 tag3])
      expect(result[:tags]).to be_a(Array)
    end

    it "raises error when non-nullable field is nil" do
      attributes = {
        id: { path: "id", type: :string, null: false }
      }
      context = build_context(attributes: attributes)
      mapper = described_class.new(context)

      response_data = {
        "data" => {
          "customer" => {
            "id" => nil
          }
        }
      }

      expect { mapper.map_response(response_data) }.to raise_error(ArgumentError, /cannot be null/)
    end

    it "returns empty hash when root data is nil" do
      attributes = {
        id: { path: "id", type: :string, null: false }
      }
      context = build_context(attributes: attributes)
      mapper = described_class.new(context)

      response_data = { "data" => { "customer" => nil } }

      result = mapper.map_response(response_data)

      expect(result).to eq({})
    end
  end

  describe "#map_node_to_attributes" do
    it "maps node data directly without response wrapper" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        name: { path: "name", type: :string, null: true }
      }
      context = build_context(attributes: attributes)
      mapper = described_class.new(context)

      node_data = {
        "id" => "gid://shopify/Customer/123",
        "name" => "John Doe"
      }

      result = mapper.map_node_to_attributes(node_data)

      expect(result).to eq({
                             id: "gid://shopify/Customer/123",
                             name: "John Doe"
                           })
    end

    it "returns empty hash for nil node data" do
      attributes = { id: { path: "id", type: :string, null: true } }
      context = build_context(attributes: attributes)
      mapper = described_class.new(context)

      result = mapper.map_node_to_attributes(nil)

      expect(result).to eq({})
    end
  end

  describe "#extract_connection_data" do
    it "returns empty hash when no connections included" do
      context = build_context(attributes: {}, included_connections: [])
      mapper = described_class.new(context)

      response_data = { "data" => { "customer" => { "id" => "123" } } }

      result = mapper.extract_connection_data(response_data)

      expect(result).to eq({})
    end
  end

  describe "#map_connection_response" do
    let(:order_class) do
      Class.new do
        include ActiveShopifyGraphQL::Base

        graphql_type 'Order'
        attribute :id
        attribute :name

        def self.name
          'Order'
        end

        def self.model_name
          ActiveModel::Name.new(self, nil, 'Order')
        end
      end
    end

    before do
      stub_const('Order', order_class)
    end

    it "maps connection response with edges" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        name: { path: "name", type: :string, null: true }
      }
      context = build_context(graphql_type: "Order", attributes: attributes, model_class: order_class)
      mapper = described_class.new(context)

      response_data = {
        "data" => {
          "orders" => {
            "edges" => [
              { "node" => { "id" => "gid://shopify/Order/1", "name" => "#1001" } },
              { "node" => { "id" => "gid://shopify/Order/2", "name" => "#1002" } }
            ]
          }
        }
      }

      result = mapper.map_connection_response(response_data, "orders")

      expect(result.length).to eq(2)
      expect(result[0]).to be_a(Order)
      expect(result[0].id).to eq("gid://shopify/Order/1")
      expect(result[1].name).to eq("#1002")
    end

    it "maps singular connection response" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        name: { path: "name", type: :string, null: true }
      }
      context = build_context(graphql_type: "Order", attributes: attributes, model_class: order_class)
      mapper = described_class.new(context)

      response_data = {
        "data" => {
          "order" => { "id" => "gid://shopify/Order/1", "name" => "#1001" }
        }
      }

      result = mapper.map_connection_response(response_data, "order", { type: :singular })

      expect(result).to be_a(Order)
      expect(result.id).to eq("gid://shopify/Order/1")
    end

    it "returns empty array when edges is nil" do
      attributes = { id: { path: "id", type: :string, null: true } }
      context = build_context(graphql_type: "Order", attributes: attributes, model_class: order_class)
      mapper = described_class.new(context)

      response_data = { "data" => { "orders" => { "edges" => nil } } }

      result = mapper.map_connection_response(response_data, "orders")

      expect(result).to eq([])
    end

    it "returns nil when singular node is nil" do
      attributes = { id: { path: "id", type: :string, null: true } }
      context = build_context(graphql_type: "Order", attributes: attributes, model_class: order_class)
      mapper = described_class.new(context)

      response_data = { "data" => { "order" => nil } }

      result = mapper.map_connection_response(response_data, "order", { type: :singular })

      expect(result).to be_nil
    end

    it "filters out nil nodes from edges" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        name: { path: "name", type: :string, null: true }
      }
      context = build_context(graphql_type: "Order", attributes: attributes, model_class: order_class)
      mapper = described_class.new(context)

      response_data = {
        "data" => {
          "orders" => {
            "edges" => [
              { "node" => { "id" => "gid://shopify/Order/1", "name" => "#1001" } },
              { "node" => nil },
              { "node" => { "id" => "gid://shopify/Order/2", "name" => "#1002" } }
            ]
          }
        }
      }

      result = mapper.map_connection_response(response_data, "orders")

      expect(result.length).to eq(2)
    end
  end
end
