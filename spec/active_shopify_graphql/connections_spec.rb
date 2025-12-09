# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Connections do
  describe ".connection" do
    it "defines connection metadata with inferred defaults" do
      customer_class = build_customer_class(with_orders: true)
      stub_const("Order", build_order_class)

      connections = customer_class.connections

      expect(connections).to have_key(:orders)
      expect(connections[:orders]).to include(
        class_name: "Order",
        query_name: "orders",
        nested: true
      )
    end

    it "allows customization of connection parameters" do
      customer_class = build_customer_class
      stub_const("Address", build_address_class)
      customer_class.connection :addresses, class_name: "Address", query_name: "mailingAddresses", default_arguments: { first: 5 }

      connections = customer_class.connections

      expect(connections[:addresses]).to include(
        class_name: "Address",
        query_name: "mailingAddresses"
      )
      expect(connections[:addresses][:default_arguments]).to include(first: 5)
    end

    it "defines connection accessor method on instances" do
      customer_class = build_customer_class(with_orders: true)
      stub_const("Order", build_order_class)
      customer = customer_class.new(id: "gid://shopify/Customer/1")

      expect(customer).to respond_to(:orders)
    end

    it "defines connection setter method for testing" do
      customer_class = build_customer_class(with_orders: true)
      stub_const("Order", build_order_class)
      customer = customer_class.new(id: "gid://shopify/Customer/1")

      expect(customer).to respond_to(:orders=)
    end

    it "stores eager_load parameter in connection metadata" do
      customer_class = build_customer_class
      stub_const("Order", build_order_class)
      customer_class.connection :orders, eager_load: true, default_arguments: { first: 10 }
      customer_class.connection :addresses, eager_load: false, default_arguments: { first: 5 }

      expect(customer_class.connections[:orders][:eager_load]).to be true
      expect(customer_class.connections[:addresses][:eager_load]).to be false
    end

    it "defaults eager_load to false" do
      customer_class = build_customer_class(with_orders: true)
      stub_const("Order", build_order_class)

      expect(customer_class.connections[:orders][:eager_load]).to be false
    end
  end

  describe ".has_many_connected" do
    it "creates a connection with type :connection" do
      customer_class = build_customer_class
      stub_const("Order", build_order_class)
      customer_class.has_many_connected :orders, default_arguments: { first: 10 }

      expect(customer_class.connections[:orders][:type]).to eq(:connection)
    end
  end

  describe ".has_one_connected" do
    it "creates a connection with type :singular" do
      line_item_class = build_line_item_class
      stub_const("ProductVariant", build_product_variant_class)
      line_item_class.has_one_connected :variant, class_name: "ProductVariant", query_name: "variant"

      expect(line_item_class.connections[:variant][:type]).to eq(:singular)
    end
  end

  describe "connection proxy" do
    it "returns a ConnectionProxy when accessing connection" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      allow(mock_loader).to receive(:load_connection_records).and_return([])
      customer = customer_class.new(id: "gid://shopify/Customer/1")

      proxy = customer.orders

      expect(proxy).to be_a(ActiveShopifyGraphQL::Connections::ConnectionProxy)
      expect(proxy.loaded?).to be false
    end

    it "loads records when proxy is accessed" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      mock_orders = [
        order_class.new(id: "gid://shopify/Order/1", name: "#1001"),
        order_class.new(id: "gid://shopify/Order/2", name: "#1002")
      ]
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)
      customer = customer_class.new(id: "gid://shopify/Customer/1")

      orders = customer.orders.to_a

      expect(orders).to eq(mock_orders)
      expect(customer.orders.loaded?).to be true
    end

    it "returns empty array when load_connection_records returns nil" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      allow(mock_loader).to receive(:load_connection_records).and_return(nil)
      customer = customer_class.new(id: "gid://shopify/Customer/1")

      orders = customer.orders.to_a

      expect(orders).to eq([])
      expect(orders).to be_a(Array)
    end

    it "implements Enumerable methods" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      mock_orders = [
        order_class.new(id: "gid://shopify/Order/1", name: "#1001"),
        order_class.new(id: "gid://shopify/Order/2", name: "#1002")
      ]
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)
      customer = customer_class.new(id: "gid://shopify/Customer/1")

      proxy = customer.orders

      expect(proxy.size).to eq(2)
      expect(proxy.first).to eq(mock_orders.first)
      expect(proxy.last).to eq(mock_orders.last)
      expect(proxy[0]).to eq(mock_orders.first)
      expect(proxy.empty?).to be false
    end

    it "supports reload" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      allow(mock_loader).to receive(:load_connection_records).and_return([])
      customer = customer_class.new(id: "gid://shopify/Customer/1")

      proxy = customer.orders
      proxy.to_a
      expect(proxy.loaded?).to be true

      proxy.reload

      expect(proxy.loaded?).to be false
    end

    it "reuses the same proxy for repeated access without options" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      mock_orders = [order_class.new(id: "gid://shopify/Order/1", name: "#1001")]
      expect(mock_loader).to receive(:load_connection_records).once.and_return(mock_orders)
      customer = customer_class.new(id: "gid://shopify/Customer/1")

      customer.orders.first
      customer.orders.first

      # The mock expectation verifies load_connection_records was called only once
    end
  end

  describe ".includes" do
    it "returns a new class for method chaining" do
      customer_class = build_customer_class(with_orders: true)
      stub_const("Customer", customer_class)
      stub_const("Order", build_order_class)

      included_class = customer_class.includes(:orders)

      expect(included_class).not_to eq(customer_class)
      expect(included_class.name).to eq("Customer")
    end

    it "validates connection names" do
      customer_class = build_customer_class(with_orders: true)
      stub_const("Customer", customer_class)
      stub_const("Order", build_order_class)

      expect { customer_class.includes(:invalid_connection) }.to raise_error(ArgumentError, /Invalid connection/)
    end

    it "supports multiple connections" do
      customer_class = build_customer_class(with_orders: true, with_addresses: true)
      stub_const("Customer", customer_class)
      stub_const("Order", build_order_class)
      stub_const("Address", build_address_class)

      included_class = customer_class.includes(:orders, :addresses)

      expect(included_class.instance_variable_get(:@included_connections)).to eq(%i[orders addresses])
    end

    it "supports nested includes syntax" do
      order_class = build_order_class(with_line_items: true)
      line_item_class = build_line_item_class(with_variant: true)
      variant_class = build_product_variant_class
      stub_const("Order", order_class)
      stub_const("LineItem", line_item_class)
      stub_const("ProductVariant", variant_class)

      expect { order_class.includes(line_items: :variant) }.not_to raise_error
    end
  end

  describe "connection caching via setter" do
    it "allows manual connection caching for testing" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      customer = customer_class.new(id: "gid://shopify/Customer/123")
      mock_orders = [order_class.new(id: "gid://shopify/Order/1", name: "#1001")]

      customer.orders = mock_orders

      expect(customer.orders).to eq(mock_orders)
    end
  end
end
