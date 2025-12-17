# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::GraphQLAssociations do
  describe ".belongs_to_graphql" do
    it "defines association metadata with inferred defaults" do
      reward_class = build_reward_class(with_customer: true)

      associations = reward_class.graphql_associations

      expect(associations).to have_key(:customer)
      expect(associations[:customer]).to include(
        type: :belongs_to,
        class_name: "Customer",
        foreign_key: "shopify_customer_id",
        loader_class: nil
      )
    end

    it "allows customization of association parameters" do
      reward_class = build_reward_class(
        with_customer: true,
        customer_options: { class_name: "Customer", foreign_key: :customer_gid }
      )
      reward_class.belongs_to_graphql :owner, class_name: "Customer", foreign_key: :customer_gid

      associations = reward_class.graphql_associations

      expect(associations[:owner]).to include(
        type: :belongs_to,
        class_name: "Customer",
        foreign_key: :customer_gid
      )
    end

    it "defines accessor method on instances" do
      reward_class = build_reward_class(with_customer: true)

      reward = reward_class.new

      expect(reward).to respond_to(:customer)
    end

    it "defines setter method for testing" do
      reward_class = build_reward_class(with_customer: true)

      reward = reward_class.new

      expect(reward).to respond_to(:customer=)
    end

    it "returns nil when foreign key is blank" do
      reward_class = build_reward_class(with_customer: true)

      reward = reward_class.new
      reward.shopify_customer_id = nil

      result = reward.customer

      expect(result).to be_nil
    end

    it "loads and caches GraphQL object when foreign key is present" do
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      mock_customer = customer_class.new(id: "gid://shopify/Customer/123", email: "test@example.com")
      allow(customer_class).to receive(:find).with("gid://shopify/Customer/123", loader: mock_loader).and_return(mock_customer)

      reward_class = build_reward_class(with_customer: true)

      reward = reward_class.new
      reward.shopify_customer_id = "gid://shopify/Customer/123"

      result = reward.customer

      expect(result).to eq(mock_customer)
      expect(result.email).to eq("test@example.com")
    end

    it "uses cached value on subsequent calls" do
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      mock_customer = customer_class.new(id: "gid://shopify/Customer/123", email: "test@example.com")
      allow(customer_class).to receive(:find).with("gid://shopify/Customer/123", loader: mock_loader).and_return(mock_customer)

      reward_class = build_reward_class(with_customer: true)

      reward = reward_class.new
      reward.shopify_customer_id = "gid://shopify/Customer/123"

      result1 = reward.customer
      result2 = reward.customer

      expect(customer_class).to have_received(:find).once
      expect(result1).to eq(result2)
      expect(result1.object_id).to eq(result2.object_id)
    end

    it "works with numeric IDs and converts to GID" do
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      mock_customer = customer_class.new(id: "gid://shopify/Customer/123", email: "test@example.com")
      allow(customer_class).to receive(:find).with(123, loader: mock_loader).and_return(mock_customer)

      reward_class = build_reward_class(with_customer: true)

      reward = reward_class.new
      reward.shopify_customer_id = 123

      result = reward.customer

      expect(result).to eq(mock_customer)
    end

    it "uses custom loader class when specified" do
      customer_class = build_customer_class
      custom_loader_class = Class.new(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      stub_const("Customer", customer_class)
      stub_const("CustomLoader", custom_loader_class)
      mock_loader = instance_double(custom_loader_class)
      allow(custom_loader_class).to receive(:new).with(customer_class).and_return(mock_loader)
      mock_customer = customer_class.new(id: "gid://shopify/Customer/123", email: "test@example.com")
      allow(customer_class).to receive(:find).with("gid://shopify/Customer/123", loader: mock_loader).and_return(mock_customer)

      reward_class = build_reward_class(with_customer: true, customer_options: { loader_class: CustomLoader })

      reward = reward_class.new
      reward.shopify_customer_id = "gid://shopify/Customer/123"

      result = reward.customer

      expect(custom_loader_class).to have_received(:new).with(customer_class)
      expect(result).to eq(mock_customer)
    end

    it "allows setter to override cached value" do
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      mock_customer = customer_class.new(id: "gid://shopify/Customer/123", email: "test@example.com")

      reward_class = build_reward_class(with_customer: true)

      reward = reward_class.new
      reward.customer = mock_customer

      result = reward.customer

      expect(result).to eq(mock_customer)
    end
  end

  describe ".has_many_graphql" do
    it "defines association metadata with inferred defaults" do
      reward_class = build_reward_class(with_variants: true)

      associations = reward_class.graphql_associations

      expect(associations).to have_key(:variants)
      expect(associations[:variants]).to include(
        type: :has_many,
        class_name: "ProductVariant",
        query_name: "variants",
        foreign_key: nil,
        primary_key: :id,
        loader_class: nil,
        query_method: :where
      )
    end

    it "allows customization of association parameters" do
      customer_class = build_ar_customer_class(
        with_orders: true,
        orders_options: { query_name: "customerOrders", foreign_key: :customer_id, primary_key: :shopify_id }
      )

      associations = customer_class.graphql_associations

      expect(associations[:orders]).to include(
        type: :has_many,
        class_name: "Order",
        query_name: "customerOrders",
        foreign_key: :customer_id,
        primary_key: :shopify_id
      )
    end

    it "defines accessor method on instances" do
      reward_class = build_reward_class(with_variants: true)

      reward = reward_class.new

      expect(reward).to respond_to(:variants)
    end

    it "defines setter method for testing" do
      reward_class = build_reward_class(with_variants: true)

      reward = reward_class.new

      expect(reward).to respond_to(:variants=)
    end

    it "returns empty array when primary key is blank" do
      reward_class = build_reward_class(with_variants: true)

      reward = reward_class.new
      reward.id = nil

      result = reward.variants

      expect(result).to eq([])
    end

    it "queries GraphQL objects without foreign key filter" do
      variant_class = build_product_variant_class
      stub_const("ProductVariant", variant_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(variant_class).to receive(:default_loader).and_return(mock_loader)
      mock_variants = [
        variant_class.new(id: "gid://shopify/ProductVariant/1", sku: "SKU-001"),
        variant_class.new(id: "gid://shopify/ProductVariant/2", sku: "SKU-002")
      ]
      allow(variant_class).to receive(:where).with({}, loader: mock_loader).and_return(mock_variants)

      reward_class = build_reward_class(with_variants: true)

      reward = reward_class.new
      reward.id = 123

      result = reward.variants

      expect(result).to eq(mock_variants)
      expect(result.size).to eq(2)
    end

    it "queries GraphQL objects with foreign key filter" do
      order_class = build_order_class
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(order_class).to receive(:default_loader).and_return(mock_loader)
      mock_orders = [
        order_class.new(id: "gid://shopify/Order/1", name: "#1001"),
        order_class.new(id: "gid://shopify/Order/2", name: "#1002")
      ]
      allow(order_class).to receive(:where).with({ customer_id: 123 }, loader: mock_loader).and_return(mock_orders)

      customer_class = build_ar_customer_class(with_orders: true, orders_options: { foreign_key: :customer_id })

      customer = customer_class.new
      customer.id = 123

      result = customer.orders

      expect(result).to eq(mock_orders)
      expect(result.size).to eq(2)
    end

    it "caches result when no runtime options provided" do
      variant_class = build_product_variant_class
      stub_const("ProductVariant", variant_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(variant_class).to receive(:default_loader).and_return(mock_loader)
      mock_variants = [
        variant_class.new(id: "gid://shopify/ProductVariant/1", sku: "SKU-001")
      ]
      allow(variant_class).to receive(:where).and_return(mock_variants)

      reward_class = build_reward_class(with_variants: true)

      reward = reward_class.new
      reward.id = 123

      result1 = reward.variants
      result2 = reward.variants

      expect(variant_class).to have_received(:where).once
      expect(result1).to eq(result2)
      expect(result1.object_id).to eq(result2.object_id)
    end

    it "does not cache when runtime options are provided" do
      variant_class = build_product_variant_class
      stub_const("ProductVariant", variant_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(variant_class).to receive(:default_loader).and_return(mock_loader)
      mock_variants = [
        variant_class.new(id: "gid://shopify/ProductVariant/1", sku: "SKU-001")
      ]
      allow(variant_class).to receive(:where).and_return(mock_variants)

      reward_class = build_reward_class(with_variants: true)

      reward = reward_class.new
      reward.id = 123

      reward.variants(limit: 5)
      reward.variants(limit: 10)

      expect(variant_class).to have_received(:where).twice
    end

    it "merges runtime options with foreign key filter" do
      order_class = build_order_class
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(order_class).to receive(:default_loader).and_return(mock_loader)
      mock_orders = [order_class.new(id: "gid://shopify/Order/1", name: "#1001")]
      allow(order_class).to receive(:where).with({ customer_id: 123, status: "open" }, loader: mock_loader).and_return(mock_orders)

      customer_class = build_ar_customer_class(with_orders: true, orders_options: { foreign_key: :customer_id })

      customer = customer_class.new
      customer.id = 123

      result = customer.orders(status: "open")

      expect(order_class).to have_received(:where).with({ customer_id: 123, status: "open" }, loader: mock_loader)
      expect(result).to eq(mock_orders)
    end

    it "uses custom loader class when specified" do
      variant_class = build_product_variant_class
      custom_loader_class = Class.new(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      stub_const("ProductVariant", variant_class)
      stub_const("CustomLoader", custom_loader_class)
      mock_loader = instance_double(custom_loader_class)
      allow(custom_loader_class).to receive(:new).with(variant_class).and_return(mock_loader)
      mock_variants = [variant_class.new(id: "gid://shopify/ProductVariant/1", sku: "SKU-001")]
      allow(variant_class).to receive(:where).with({}, loader: mock_loader).and_return(mock_variants)

      reward_class = build_reward_class(with_variants: true, variants_options: { loader_class: CustomLoader })

      reward = reward_class.new
      reward.id = 123

      result = reward.variants

      expect(custom_loader_class).to have_received(:new).with(variant_class)
      expect(result).to eq(mock_variants)
    end

    it "allows setter to override cached value" do
      variant_class = build_product_variant_class
      stub_const("ProductVariant", variant_class)
      mock_variants = [variant_class.new(id: "gid://shopify/ProductVariant/1", sku: "SKU-001")]

      reward_class = build_reward_class(with_variants: true)

      reward = reward_class.new
      reward.variants = mock_variants

      result = reward.variants

      expect(result).to eq(mock_variants)
    end

    it "returns empty array for connection query_method" do
      line_item_class = build_line_item_class
      stub_const("LineItem", line_item_class)

      reward_class = build_reward_class
      reward_class.has_many_graphql :items, class_name: "LineItem", query_method: :connection

      reward = reward_class.new
      reward.id = 123

      result = reward.items

      expect(result).to eq([])
    end
  end

  describe "duck typing compatibility" do
    it "works with objects that respond_to foreign key method" do
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      mock_customer = customer_class.new(id: "gid://shopify/Customer/123", email: "test@example.com")
      allow(customer_class).to receive(:find).with("gid://shopify/Customer/123", loader: mock_loader).and_return(mock_customer)

      # Create a plain Ruby object (not ActiveRecord)
      plain_object_class = build_plain_object_class(with_customer: true)

      plain_object = plain_object_class.new(shopify_customer_id: "gid://shopify/Customer/123")

      result = plain_object.customer

      expect(result).to eq(mock_customer)
      expect(result.email).to eq("test@example.com")
    end
  end
end
