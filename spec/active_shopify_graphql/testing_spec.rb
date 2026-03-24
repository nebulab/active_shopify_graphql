# frozen_string_literal: true

require "spec_helper"
require "active_shopify_graphql/testing"

RSpec.describe ActiveShopifyGraphQL::Testing do
  before(:each) { described_class.enable! }
  after(:each) { described_class.reset! }

  let(:customer_class) { build_customer_class(with_orders: true) }
  let(:order_class) { build_order_class }
  let(:product_variant_class) { build_product_variant_class }

  before do
    stub_const("Customer", customer_class)
    stub_const("Order", order_class)
    stub_const("ProductVariant", product_variant_class)
  end

  describe ".enable! / .reset! / .enabled?" do
    it "tracks the enabled state" do
      described_class.reset!
      expect(described_class.enabled?).to be false

      described_class.enable!
      expect(described_class.enabled?).to be true
    end

    it "clears the store on reset" do
      described_class.register(customer_class, [{ id: 1, email: "a@b.com" }])
      described_class.reset!

      described_class.enable!
      expect(customer_class.where(email: "a@b.com").to_a).to be_empty
    end
  end

  describe ".register" do
    it "normalizes bare integer IDs to GIDs" do
      described_class.register(customer_class, [{ id: 1, email: "john@example.com" }])

      customer = customer_class.find(1)
      expect(customer.id).to eq("gid://shopify/Customer/1")
      expect(customer.email).to eq("john@example.com")
    end

    it "preserves existing GIDs" do
      described_class.register(customer_class, [
                                 { id: "gid://shopify/Customer/42", email: "jane@example.com" }
                               ])

      customer = customer_class.find(42)
      expect(customer.id).to eq("gid://shopify/Customer/42")
    end
  end

  describe "find" do
    before do
      described_class.register(customer_class, [
                                 { id: 1, email: "john@example.com", display_name: "John" },
                                 { id: 2, email: "jane@example.com", display_name: "Jane" }
                               ])
    end

    it "finds a record by bare integer ID" do
      customer = customer_class.find(1)
      expect(customer).to be_a(customer_class)
      expect(customer.email).to eq("john@example.com")
    end

    it "finds a record by GID string" do
      customer = customer_class.find("gid://shopify/Customer/2")
      expect(customer.email).to eq("jane@example.com")
    end

    it "raises ObjectNotFoundError for missing records" do
      expect { customer_class.find(999) }.to raise_error(ActiveShopifyGraphQL::ObjectNotFoundError)
    end
  end

  describe "where" do
    before do
      described_class.register(customer_class, [
                                 { id: 1, email: "john@example.com", display_name: "John" },
                                 { id: 2, email: "jane@example.com", display_name: "Jane" },
                                 { id: 3, email: "john@other.com", display_name: "John" }
                               ])
    end

    it "filters by hash conditions" do
      results = customer_class.where(email: "john@example.com").to_a
      expect(results.size).to eq(1)
      expect(results.first.email).to eq("john@example.com")
    end

    it "filters by multiple conditions" do
      results = customer_class.where(display_name: "John").to_a
      expect(results.size).to eq(2)
    end

    it "returns empty array when no records match" do
      results = customer_class.where(email: "nobody@example.com").to_a
      expect(results).to be_empty
    end
  end

  describe "find_by" do
    before do
      described_class.register(customer_class, [
                                 { id: 1, email: "john@example.com", display_name: "John" }
                               ])
    end

    it "returns the first matching record" do
      customer = customer_class.find_by(email: "john@example.com")
      expect(customer).to be_a(customer_class)
      expect(customer.display_name).to eq("John")
    end

    it "returns nil when no record matches" do
      customer = customer_class.find_by(email: "nobody@example.com")
      expect(customer).to be_nil
    end
  end

  describe "search fields (non-attribute filtering)" do
    it "matches on search fields that are not model attributes" do
      described_class.register(product_variant_class, [
                                 { id: 1, sku: "ABC", product_id: 10 },
                                 { id: 2, sku: "DEF", product_id: 20 }
                               ])

      results = product_variant_class.where(product_id: 10).to_a
      expect(results.size).to eq(1)
      expect(results.first.sku).to eq("ABC")
    end

    it "strips search fields from model attributes" do
      described_class.register(product_variant_class, [
                                 { id: 1, sku: "ABC", product_id: 10 }
                               ])

      variant = product_variant_class.find(1)
      expect(variant).not_to respond_to(:product_id)
      expect(variant.sku).to eq("ABC")
    end
  end

  describe "includes (eager loading)" do
    before do
      described_class.register(customer_class, [
                                 {
                                   id: 1,
                                   email: "john@example.com",
                                   display_name: "John",
                                   orders: [
                                     { id: "gid://shopify/Order/100", name: "#1001" },
                                     { id: "gid://shopify/Order/101", name: "#1002" }
                                   ]
                                 }
                               ])
    end

    it "eager loads connections" do
      customer = customer_class.includes(:orders).find(1)
      expect(customer.email).to eq("john@example.com")

      orders = customer.orders
      expect(orders.size).to eq(2)
      expect(orders.first).to be_a(order_class)
      expect(orders.first.name).to eq("#1001")
    end

    it "returns from connection cache without lazy loading" do
      customer = customer_class.includes(:orders).find(1)

      # Access orders — should come from the connection cache
      cache = customer.instance_variable_get(:@_connection_cache)
      expect(cache).to have_key(:orders)
      expect(cache[:orders].size).to eq(2)
    end
  end

  describe "lazy-loaded connections" do
    before do
      described_class.register(customer_class, [
                                 {
                                   id: 1,
                                   email: "john@example.com",
                                   display_name: "John",
                                   orders: [
                                     { id: "gid://shopify/Order/100", name: "#1001" }
                                   ]
                                 }
                               ])
    end

    it "lazy-loads connections from the store" do
      customer = customer_class.find(1)

      # No connection cache set (no includes)
      cache = customer.instance_variable_get(:@_connection_cache)
      expect(cache).to be_nil

      # Accessing orders triggers lazy load via TestLoader
      orders = customer.orders.to_a
      expect(orders.size).to eq(1)
      expect(orders.first.name).to eq("#1001")
    end
  end

  describe "pagination" do
    before do
      described_class.register(customer_class, [
                                 { id: 1, email: "a@example.com", display_name: "A" },
                                 { id: 2, email: "b@example.com", display_name: "B" },
                                 { id: 3, email: "c@example.com", display_name: "C" },
                                 { id: 4, email: "d@example.com", display_name: "D" },
                                 { id: 5, email: "e@example.com", display_name: "E" }
                               ])
    end

    it "returns paginated results" do
      page = customer_class.all.in_pages(of: 2)
      expect(page.size).to eq(2)
      expect(page.has_next_page?).to be true
      expect(page.first.email).to eq("a@example.com")
    end

    it "supports next_page navigation" do
      page1 = customer_class.all.in_pages(of: 2)
      page2 = page1.next_page
      expect(page2.size).to eq(2)
      expect(page2.first.email).to eq("c@example.com")
    end
  end

  describe "perform_graphql_query" do
    it "raises if called directly" do
      loader = ActiveShopifyGraphQL::Testing::TestLoader.new(customer_class)
      expect { loader.perform_graphql_query("query { }") }.to raise_error(RuntimeError, /should not execute GraphQL/)
    end
  end

  describe "test isolation" do
    it "each test starts with a clean store after reset" do
      described_class.register(customer_class, [{ id: 1, email: "test@example.com" }])
      expect(customer_class.find_by(email: "test@example.com")).not_to be_nil

      described_class.reset!
      described_class.enable!

      expect(customer_class.find_by(email: "test@example.com")).to be_nil
    end
  end

  describe "when testing is disabled" do
    it "does not intercept loader creation" do
      described_class.reset!

      # With testing disabled, default_loader_class should return AdminApiLoader
      expect(customer_class.send(:default_loader_class)).to eq(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
    end
  end
end
