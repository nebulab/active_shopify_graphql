# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Response::ResponseMapper do
  describe "#map_response" do
    it "maps simple flat attributes from response" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        email: { path: "email", type: :string, null: true }
      }
      context = build_loader_context(attributes: attributes)
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
      context = build_loader_context(graphql_type: "Order", attributes: attributes)
      mapper = described_class.new(context)
      response_data = {
        "data" => {
          "order" => {
            "id" => "gid://shopify/Order/456",
            "totalPriceSet" => {
              "shopMoney" => { "amount" => "99.99" }
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

    it "coerces integer type values" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        count: { path: "orderCount", type: :integer, null: true }
      }
      context = build_loader_context(attributes: attributes)
      mapper = described_class.new(context)
      # Response uses aliased key 'count' (attr_name) since query generates: count: orderCount
      response_data = {
        "data" => {
          "customer" => {
            "id" => "123",
            "count" => "42"
          }
        }
      }

      result = mapper.map_response(response_data)

      expect(result[:count]).to eq(42)
    end

    it "coerces boolean type values" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        active: { path: "active", type: :boolean, null: true }
      }
      context = build_loader_context(attributes: attributes)
      mapper = described_class.new(context)
      response_data = {
        "data" => {
          "customer" => {
            "id" => "123",
            "active" => "true"
          }
        }
      }

      result = mapper.map_response(response_data)

      expect(result[:active]).to be true
    end

    it "applies transform functions" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        tags: { path: "tags", type: :string, null: true, transform: ->(v) { v&.join(", ") } }
      }
      context = build_loader_context(attributes: attributes)
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

    it "uses default values when field is nil" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        status: { path: "status", type: :string, null: true, default: "pending" }
      }
      context = build_loader_context(attributes: attributes)
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
      context = build_loader_context(attributes: attributes)
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
    end

    it "raises error for null values when null is not allowed" do
      attributes = {
        required_field: { path: "requiredField", type: :string, null: false }
      }
      context = build_loader_context(attributes: attributes)
      mapper = described_class.new(context)
      response_data = {
        "data" => {
          "customer" => {
            "requiredField" => nil
          }
        }
      }

      expect { mapper.map_response(response_data) }.to raise_error(ArgumentError, /cannot be null/)
    end

    it "returns empty hash when root data is nil" do
      attributes = {
        id: { path: "id", type: :string, null: false }
      }
      context = build_loader_context(attributes: attributes)
      mapper = described_class.new(context)
      response_data = { "data" => { "customer" => nil } }

      result = mapper.map_response(response_data)

      expect(result).to eq({})
    end
  end

  describe "#map_node_to_attributes" do
    it "maps node data directly without root path traversal" do
      attributes = {
        id: { path: "id", type: :string, null: false },
        name: { path: "displayName", type: :string, null: true }
      }
      context = build_loader_context(attributes: attributes)
      mapper = described_class.new(context)
      # Response uses aliased key 'name' (attr_name) since query generates: name: displayName
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
      attributes = {
        id: { path: "id", type: :string, null: false }
      }
      context = build_loader_context(attributes: attributes)
      mapper = described_class.new(context)

      result = mapper.map_node_to_attributes(nil)

      expect(result).to eq({})
    end
  end

  describe "#extract_connection_data" do
    it "extracts connection data using original_name as response key" do
      order_class = build_order_class
      stub_const("Order", order_class)

      model_class = build_loader_protocol_class(
        graphql_type: "Customer",
        connections: {
          recent_orders: {
            class_name: "Order",
            query_name: "orders",
            original_name: :recent_orders,
            type: :connection,
            default_arguments: { first: 5 }
          }
        }
      )
      context = build_loader_context(
        graphql_type: "Customer",
        attributes: { id: { path: "id", type: :string } },
        model_class: model_class,
        included_connections: [:recent_orders]
      )
      mapper = described_class.new(context)
      # Response uses aliased key "recent_orders" not "orders"
      response_data = {
        "data" => {
          "customer" => {
            "id" => "gid://shopify/Customer/123",
            "recent_orders" => {
              "nodes" => [
                { "id" => "gid://shopify/Order/1" },
                { "id" => "gid://shopify/Order/2" }
              ]
            }
          }
        }
      }

      result = mapper.extract_connection_data(response_data)

      expect(result).to have_key(:recent_orders)
      expect(result[:recent_orders].length).to eq(2)
    end

    it "handles multiple connections with same query_name using different aliases" do
      order_class = build_order_class
      stub_const("Order", order_class)

      model_class = build_loader_protocol_class(
        graphql_type: "Customer",
        connections: {
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
            default_arguments: { first: 5, reverse: true }
          }
        }
      )
      context = build_loader_context(
        graphql_type: "Customer",
        attributes: { id: { path: "id", type: :string } },
        model_class: model_class,
        included_connections: %i[orders recent_orders]
      )
      mapper = described_class.new(context)
      # Each connection has its own aliased response key
      response_data = {
        "data" => {
          "customer" => {
            "id" => "gid://shopify/Customer/123",
            "orders" => {
              "nodes" => [
                { "id" => "gid://shopify/Order/old1" },
                { "id" => "gid://shopify/Order/old2" }
              ]
            },
            "recent_orders" => {
              "nodes" => [
                { "id" => "gid://shopify/Order/new1" },
                { "id" => "gid://shopify/Order/new2" },
                { "id" => "gid://shopify/Order/new3" }
              ]
            }
          }
        }
      }

      result = mapper.extract_connection_data(response_data)

      expect(result[:orders].length).to eq(2)
      expect(result[:recent_orders].length).to eq(3)
      expect(result[:orders].first.id).to eq("gid://shopify/Order/old1")
      expect(result[:recent_orders].first.id).to eq("gid://shopify/Order/new1")
    end
  end

  describe "raw_graphql attribute mapping" do
    it "extracts raw_graphql attribute value using attr_name as response key" do
      raw_gql = 'metafield(namespace: "custom", key: "roaster") { value }'
      attributes = {
        id: { path: "id", type: :string },
        # Use path to dig into the value field
        roaster: { path: "roaster.value", type: :string, raw_graphql: raw_gql }
      }
      context = build_loader_context(attributes: attributes)
      mapper = described_class.new(context)
      # Response has aliased key "roaster" (from "roaster: metafield(...)")
      response_data = {
        "data" => {
          "customer" => {
            "id" => "gid://shopify/Customer/123",
            "roaster" => {
              "value" => "Acme Coffee Roasters"
            }
          }
        }
      }

      result = mapper.map_response(response_data)

      # Path "roaster.value" digs into the response
      expect(result[:roaster]).to eq("Acme Coffee Roasters")
    end

    it "digs into nested path for raw_graphql attributes" do
      raw_gql = 'metafield(namespace: "custom", key: "roaster") { reference { ... on MetaObject { id } } }'
      attributes = {
        id: { path: "id", type: :string },
        roaster_id: { path: "roaster_id.reference.id", type: :string, raw_graphql: raw_gql }
      }
      context = build_loader_context(attributes: attributes)
      mapper = described_class.new(context)
      # Response has aliased key "roaster_id"
      response_data = {
        "data" => {
          "customer" => {
            "id" => "gid://shopify/Customer/123",
            "roaster_id" => {
              "reference" => {
                "id" => "gid://shopify/Metaobject/456"
              }
            }
          }
        }
      }

      result = mapper.map_response(response_data)

      expect(result[:roaster_id]).to eq("gid://shopify/Metaobject/456")
    end
  end

  describe "#map_nested_connection_response" do
    it "uses lowerCamelCase for multi-word parent GraphQL types" do
      product_class = build_product_class
      stub_const("Product", product_class)

      context = build_loader_context(graphql_type: "Product", attributes: { id: { path: "id", type: :string }, title: { path: "title", type: :string } }, model_class: product_class)
      mapper = described_class.new(context)

      parent_class = build_product_variant_class
      stub_const("ProductVariant", parent_class)
      parent = parent_class.new
      parent.id = "gid://shopify/ProductVariant/456"

      response_data = {
        "data" => {
          "productVariant" => {
            "product" => {
              "id" => "gid://shopify/Product/123",
              "title" => "Test Product"
            }
          }
        }
      }

      result = mapper.map_nested_connection_response(response_data, "product", parent, { type: :singular })

      # ResponseMapper now returns attributes, not instances
      expect(result).to be_a(Hash)
      expect(result[:id]).to eq("gid://shopify/Product/123")
      expect(result[:title]).to eq("Test Product")
    end
  end

  describe "inverse_of support in extract_connection_data" do
    it "populates inverse cache on has_many connection records during eager loading" do
      product_class = Class.new(ActiveShopifyGraphQL::Model) do
        attribute :id
        attribute :title

        define_singleton_method(:name) { "Product" }
        define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "Product") }
      end
      product_class.graphql_type("Product")

      variant_class = Class.new(ActiveShopifyGraphQL::Model) do
        attribute :id
        attribute :sku

        define_singleton_method(:name) { "ProductVariant" }
        define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "ProductVariant") }
      end
      variant_class.graphql_type("ProductVariant")
      variant_class.has_one_connected :product, class_name: "Product"

      stub_const("Product", product_class)
      stub_const("ProductVariant", variant_class)

      product_class.has_many_connected :variants, class_name: "ProductVariant", default_arguments: { first: 10 }
      product_class.connections[:variants][:inverse_of] = :product
      variant_class.connections[:product][:inverse_of] = :variants

      context = ActiveShopifyGraphQL::LoaderContext.new(
        graphql_type: "Product",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: { id: { path: "id", type: :string }, title: { path: "title", type: :string } },
        model_class: product_class,
        included_connections: [:variants]
      )
      mapper = described_class.new(context)
      parent_instance = product_class.new(id: "gid://shopify/Product/123", title: "Test Product")
      response_data = {
        "data" => {
          "product" => {
            "id" => "gid://shopify/Product/123",
            "title" => "Test Product",
            "variants" => {
              "nodes" => [
                { "id" => "gid://shopify/ProductVariant/1", "sku" => "SKU1" },
                { "id" => "gid://shopify/ProductVariant/2", "sku" => "SKU2" }
              ]
            }
          }
        }
      }

      result = mapper.extract_connection_data(response_data, parent_instance: parent_instance)

      expect(result[:variants]).to be_an(Array)
      expect(result[:variants].length).to eq(2)
      variant1 = result[:variants][0]
      variant2 = result[:variants][1]
      expect(variant1.instance_variable_get(:@_connection_cache)[:product]).to eq(parent_instance)
      expect(variant2.instance_variable_get(:@_connection_cache)[:product]).to eq(parent_instance)
    end

    it "populates inverse cache on singular connection record during eager loading" do
      product_class = Class.new(ActiveShopifyGraphQL::Model) do
        attribute :id
        attribute :title

        define_singleton_method(:name) { "Product" }
        define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "Product") }
      end
      product_class.graphql_type("Product")

      variant_class = Class.new(ActiveShopifyGraphQL::Model) do
        attribute :id
        attribute :sku

        define_singleton_method(:name) { "ProductVariant" }
        define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "ProductVariant") }
      end
      variant_class.graphql_type("ProductVariant")

      stub_const("Product", product_class)
      stub_const("ProductVariant", variant_class)

      product_class.has_many_connected :variants, class_name: "ProductVariant", default_arguments: { first: 10 }
      variant_class.has_one_connected :product, class_name: "Product"
      product_class.connections[:variants][:inverse_of] = :product
      variant_class.connections[:product][:inverse_of] = :variants

      # Test extracting a singular connection from variant's perspective
      # When a variant has a product connection, and we extract it, the product should have
      # the variant cached in its inverse (variants) connection
      variant_context = ActiveShopifyGraphQL::LoaderContext.new(
        graphql_type: "ProductVariant",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: { id: { path: "id", type: :string }, sku: { path: "sku", type: :string } },
        model_class: variant_class,
        included_connections: [:product]
      )
      variant_mapper = described_class.new(variant_context)
      variant_instance = variant_class.new(id: "gid://shopify/ProductVariant/1", sku: "SKU1")
      response_data = {
        "data" => {
          "productVariant" => {
            "id" => "gid://shopify/ProductVariant/1",
            "sku" => "SKU1",
            "product" => {
              "id" => "gid://shopify/Product/123",
              "title" => "Test Product"
            }
          }
        }
      }

      result = variant_mapper.extract_connection_data(response_data, parent_instance: variant_instance)

      expect(result[:product]).to be_a(Product)
      product = result[:product]
      # The product should have the variant in its inverse cache
      expect(product.instance_variable_get(:@_connection_cache)[:variants]).to eq([variant_instance])
    end

    it "handles missing inverse connection gracefully" do
      product_class = Class.new(ActiveShopifyGraphQL::Model) do
        attribute :id
        attribute :title

        define_singleton_method(:name) { "Product" }
        define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "Product") }
      end
      product_class.graphql_type("Product")

      variant_class = Class.new(ActiveShopifyGraphQL::Model) do
        attribute :id
        attribute :sku

        define_singleton_method(:name) { "ProductVariant" }
        define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "ProductVariant") }
      end
      variant_class.graphql_type("ProductVariant")

      stub_const("Product", product_class)
      stub_const("ProductVariant", variant_class)

      product_class.has_many_connected :variants, class_name: "ProductVariant", default_arguments: { first: 10 }
      product_class.connections[:variants][:inverse_of] = :nonexistent_connection

      context = ActiveShopifyGraphQL::LoaderContext.new(
        graphql_type: "Product",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: { id: { path: "id", type: :string }, title: { path: "title", type: :string } },
        model_class: product_class,
        included_connections: [:variants]
      )
      mapper = described_class.new(context)
      parent_instance = product_class.new(id: "gid://shopify/Product/123", title: "Test Product")
      response_data = {
        "data" => {
          "product" => {
            "id" => "gid://shopify/Product/123",
            "title" => "Test Product",
            "variants" => {
              "nodes" => [
                { "id" => "gid://shopify/ProductVariant/1", "sku" => "SKU1" }
              ]
            }
          }
        }
      }

      result = mapper.extract_connection_data(response_data, parent_instance: parent_instance)

      expect(result[:variants]).to be_an(Array)
      expect(result[:variants].length).to eq(1)
      variant = result[:variants][0]
      cache = variant.instance_variable_get(:@_connection_cache)
      expect(cache).to be_nil.or be_empty
    end

    it "works without inverse_of specified" do
      product_class = Class.new(ActiveShopifyGraphQL::Model) do
        attribute :id
        attribute :title

        define_singleton_method(:name) { "Product" }
        define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "Product") }
      end
      product_class.graphql_type("Product")

      variant_class = Class.new(ActiveShopifyGraphQL::Model) do
        attribute :id
        attribute :sku

        define_singleton_method(:name) { "ProductVariant" }
        define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "ProductVariant") }
      end
      variant_class.graphql_type("ProductVariant")

      stub_const("Product", product_class)
      stub_const("ProductVariant", variant_class)

      product_class.has_many_connected :variants, class_name: "ProductVariant", default_arguments: { first: 10 }

      context = ActiveShopifyGraphQL::LoaderContext.new(
        graphql_type: "Product",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: { id: { path: "id", type: :string }, title: { path: "title", type: :string } },
        model_class: product_class,
        included_connections: [:variants]
      )
      mapper = described_class.new(context)
      parent_instance = product_class.new(id: "gid://shopify/Product/123", title: "Test Product")
      response_data = {
        "data" => {
          "product" => {
            "id" => "gid://shopify/Product/123",
            "title" => "Test Product",
            "variants" => {
              "nodes" => [
                { "id" => "gid://shopify/ProductVariant/1", "sku" => "SKU1" }
              ]
            }
          }
        }
      }

      result = mapper.extract_connection_data(response_data, parent_instance: parent_instance)

      expect(result[:variants]).to be_an(Array)
      expect(result[:variants].length).to eq(1)
      variant = result[:variants][0]
      expect(variant.instance_variable_get(:@_connection_cache)).to be_nil
    end

    it "handles nested connections with inverse_of recursively" do
      customer_class = Class.new(ActiveShopifyGraphQL::Model) do
        attribute :id
        attribute :email

        define_singleton_method(:name) { "Customer" }
        define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "Customer") }
      end
      customer_class.graphql_type("Customer")

      order_class = Class.new(ActiveShopifyGraphQL::Model) do
        attribute :id
        attribute :name

        define_singleton_method(:name) { "Order" }
        define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "Order") }
      end
      order_class.graphql_type("Order")

      line_item_class = Class.new(ActiveShopifyGraphQL::Model) do
        attribute :id
        attribute :quantity

        define_singleton_method(:name) { "LineItem" }
        define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "LineItem") }
      end
      line_item_class.graphql_type("LineItem")

      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      stub_const("LineItem", line_item_class)

      customer_class.has_many_connected :orders, class_name: "Order", default_arguments: { first: 5 }
      order_class.has_one_connected :customer, class_name: "Customer"
      order_class.has_many_connected :line_items, class_name: "LineItem", default_arguments: { first: 10 }
      line_item_class.has_one_connected :order, class_name: "Order"

      customer_class.connections[:orders][:inverse_of] = :customer
      order_class.connections[:customer][:inverse_of] = :orders
      order_class.connections[:line_items][:inverse_of] = :order
      line_item_class.connections[:order][:inverse_of] = :line_items

      context = ActiveShopifyGraphQL::LoaderContext.new(
        graphql_type: "Customer",
        loader_class: ActiveShopifyGraphQL::Loaders::AdminApiLoader,
        defined_attributes: { id: { path: "id", type: :string }, email: { path: "email", type: :string } },
        model_class: customer_class,
        included_connections: [{ orders: [:line_items] }]
      )
      mapper = described_class.new(context)
      parent_instance = customer_class.new(id: "gid://shopify/Customer/1", email: "test@example.com")
      response_data = {
        "data" => {
          "customer" => {
            "id" => "gid://shopify/Customer/1",
            "email" => "test@example.com",
            "orders" => {
              "nodes" => [
                {
                  "id" => "gid://shopify/Order/100",
                  "name" => "#1001",
                  "line_items" => {
                    "nodes" => [
                      { "id" => "gid://shopify/LineItem/1", "quantity" => 2 },
                      { "id" => "gid://shopify/LineItem/2", "quantity" => 1 }
                    ]
                  }
                }
              ]
            }
          }
        }
      }

      result = mapper.extract_connection_data(response_data, parent_instance: parent_instance)

      expect(result[:orders]).to be_an(Array)
      expect(result[:orders].length).to eq(1)
      order = result[:orders][0]
      expect(order.instance_variable_get(:@_connection_cache)[:customer]).to eq(parent_instance)

      line_items = order.instance_variable_get(:@_connection_cache)[:line_items]
      expect(line_items).to be_an(Array)
      expect(line_items.length).to eq(2)
      expect(line_items[0].instance_variable_get(:@_connection_cache)[:order]).to eq(order)
      expect(line_items[1].instance_variable_get(:@_connection_cache)[:order]).to eq(order)
    end
  end
end
