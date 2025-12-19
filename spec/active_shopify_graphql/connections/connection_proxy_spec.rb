# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Connections::ConnectionProxy do
  describe "#initialize" do
    it "creates a new ConnectionProxy with required parameters" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      allow(mock_loader).to receive(:load_connection_records).and_return([])
      parent = customer_class.new(id: "gid://shopify/Customer/123")

      proxy = described_class.new(
        parent: parent,
        connection_name: :orders,
        connection_config: customer_class.connections[:orders],
        options: {}
      )

      expect(proxy).to be_a(described_class)
      expect(proxy.loaded?).to be false
    end
  end

  describe "#loaded?" do
    it "returns false before loading" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      allow(mock_loader).to receive(:load_connection_records).and_return([])
      parent = customer_class.new(id: "gid://shopify/Customer/123")

      proxy = parent.orders

      expect(proxy.loaded?).to be false
    end

    it "returns true after loading" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      allow(mock_loader).to receive(:load_connection_records).and_return([])
      parent = customer_class.new(id: "gid://shopify/Customer/123")

      proxy = parent.orders
      proxy.to_a

      expect(proxy.loaded?).to be true
    end
  end

  describe "#reload" do
    it "clears loaded state" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      allow(mock_loader).to receive(:load_connection_records).and_return([])
      parent = customer_class.new(id: "gid://shopify/Customer/123")
      proxy = parent.orders
      proxy.to_a
      expect(proxy.loaded?).to be true

      proxy.reload

      expect(proxy.loaded?).to be false
    end
  end

  describe "#load" do
    it "loads the connection records and returns the proxy" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      mock_orders = [
        order_class.new(id: "gid://shopify/Order/1"),
        order_class.new(id: "gid://shopify/Order/2")
      ]
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)
      parent = customer_class.new(id: "gid://shopify/Customer/123")

      proxy = parent.orders
      expect(proxy.loaded?).to be false

      result = proxy.load
      expect(result).to eq(proxy)
      expect(proxy.loaded?).to be true
      expect(proxy.to_a).to eq(mock_orders)
    end
  end

  describe "Enumerable methods" do
    it "delegates size to loaded records" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      mock_orders = [
        order_class.new(id: "gid://shopify/Order/1"),
        order_class.new(id: "gid://shopify/Order/2")
      ]
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)
      parent = customer_class.new(id: "gid://shopify/Customer/123")

      expect(parent.orders.size).to eq(2)
    end

    it "delegates first to loaded records" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      first_order = order_class.new(id: "gid://shopify/Order/1")
      mock_orders = [first_order, order_class.new(id: "gid://shopify/Order/2")]
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)
      parent = customer_class.new(id: "gid://shopify/Customer/123")

      expect(parent.orders.first).to eq(first_order)
    end

    it "delegates last to loaded records" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      last_order = order_class.new(id: "gid://shopify/Order/2")
      mock_orders = [order_class.new(id: "gid://shopify/Order/1"), last_order]
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)
      parent = customer_class.new(id: "gid://shopify/Customer/123")

      expect(parent.orders.last).to eq(last_order)
    end

    it "delegates [] to loaded records" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      first_order = order_class.new(id: "gid://shopify/Order/1")
      mock_orders = [first_order, order_class.new(id: "gid://shopify/Order/2")]
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)
      parent = customer_class.new(id: "gid://shopify/Customer/123")

      expect(parent.orders[0]).to eq(first_order)
    end

    it "delegates empty? to loaded records" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      allow(mock_loader).to receive(:load_connection_records).and_return([])
      parent = customer_class.new(id: "gid://shopify/Customer/123")

      expect(parent.orders.empty?).to be true
    end

    it "supports each iteration" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      mock_orders = [
        order_class.new(id: "gid://shopify/Order/1"),
        order_class.new(id: "gid://shopify/Order/2")
      ]
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)
      parent = customer_class.new(id: "gid://shopify/Customer/123")

      ids = parent.orders.map(&:id)

      expect(ids).to eq(["gid://shopify/Order/1", "gid://shopify/Order/2"])
    end

    it "supports map operation" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      mock_orders = [
        order_class.new(id: "gid://shopify/Order/1"),
        order_class.new(id: "gid://shopify/Order/2")
      ]
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)
      parent = customer_class.new(id: "gid://shopify/Customer/123")

      ids = parent.orders.map(&:id)

      expect(ids).to eq(["gid://shopify/Order/1", "gid://shopify/Order/2"])
    end
  end

  describe "#inspect" do
    it "loads the records and returns their inspection string" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      mock_orders = [
        order_class.new(id: "gid://shopify/Order/1"),
        order_class.new(id: "gid://shopify/Order/2")
      ]
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)
      parent = customer_class.new(id: "gid://shopify/Customer/123")
      proxy = parent.orders

      expect(proxy.inspect).to eq(mock_orders.inspect)
      expect(proxy.loaded?).to be true
    end
  end

  describe "#pretty_print" do
    it "delegates to records" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      mock_orders = [
        order_class.new(id: "gid://shopify/Order/1"),
        order_class.new(id: "gid://shopify/Order/2")
      ]
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)
      parent = customer_class.new(id: "gid://shopify/Customer/123")
      proxy = parent.orders

      # Ensure loaded
      proxy.load
      records = proxy.instance_variable_get(:@records)
      allow(records).to receive(:pretty_print)

      q = double("q")
      proxy.pretty_print(q)

      expect(records).to have_received(:pretty_print).with(q)
    end
  end
end
