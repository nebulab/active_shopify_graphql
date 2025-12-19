# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Query::Relation do
  mock_client = nil

  before do
    mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
    allow(mock_client).to receive(:execute).and_return(
      { "data" => {} }
    )
    ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
  end

  describe "#initialize" do
    it "stores the model class" do
      product_class = build_product_class(with_variants: true)

      relation = described_class.new(product_class)

      expect(relation.model_class).to eq(product_class)
    end

    it "accepts included connections" do
      product_class = build_product_class(with_variants: true)

      relation = described_class.new(product_class, included_connections: [:variants])

      expect(relation.included_connections).to eq([:variants])
    end

    it "accepts conditions" do
      product_class = build_product_class

      relation = described_class.new(product_class, conditions: { title: "Test" })

      expect(relation.conditions).to eq(title: "Test")
    end
  end

  describe "#includes" do
    it "returns a new relation with included connections" do
      product_class = build_product_class(with_variants: true)
      stub_const("Product", product_class)
      stub_const("ProductVariant", build_product_variant_class)

      relation = described_class.new(product_class)
      result = relation.includes(:variants)

      expect(result).to be_a(described_class)
      expect(result.included_connections).to include(:variants)
    end

    it "validates connection names" do
      product_class = build_product_class

      relation = described_class.new(product_class)

      expect { relation.includes(:nonexistent) }.to raise_error(ArgumentError, /Invalid connection/)
    end

    it "allows chaining includes calls" do
      customer_class = build_customer_class(with_orders: true, with_addresses: true)
      stub_const("Customer", customer_class)
      stub_const("Order", build_order_class)
      stub_const("Address", build_address_class)

      relation = described_class.new(customer_class)
      result = relation.includes(:orders).includes(:addresses)

      expect(result.included_connections).to include(:orders, :addresses)
    end

    it "deduplicates connection names" do
      customer_class = build_customer_class(with_orders: true)
      stub_const("Customer", customer_class)
      stub_const("Order", build_order_class)

      relation = described_class.new(customer_class)
      result = relation.includes(:orders).includes(:orders)

      expect(result.included_connections.count(:orders)).to eq(1)
    end
  end

  describe "#where" do
    it "returns a new relation with conditions" do
      product_class = build_product_class
      stub_const("Product", product_class)

      relation = described_class.new(product_class)
      result = relation.where(title: "test")

      expect(result).to be_a(described_class)
      expect(result.conditions).to eq(title: "test")
    end

    it "supports string conditions with parameter binding" do
      product_class = build_product_class
      stub_const("Product", product_class)

      relation = described_class.new(product_class)
      result = relation.where("sku:?", "ABC-123")

      expect(result).to be_a(described_class)
      expect(result.conditions).to eq(["sku:?", "ABC-123"])
    end

    it "supports string conditions with named parameter binding" do
      product_class = build_product_class
      stub_const("Product", product_class)

      relation = described_class.new(product_class)
      result = relation.where("sku::sku", sku: "ABC-123")

      expect(result).to be_a(described_class)
      expect(result.conditions).to eq(["sku::sku", { sku: "ABC-123" }])
    end
  end

  describe "#find_by" do
    it "returns nil when no records match" do
      product_class = build_product_class
      stub_const("Product", product_class)
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      allow(mock_client).to receive(:execute).and_return({ "data" => { "products" => { "edges" => [] } } })
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }

      relation = described_class.new(product_class)
      result = relation.find_by(title: "nonexistent")

      expect(result).to be_nil
    end
  end

  describe "#select" do
    it "returns a new relation with selected attributes" do
      product_class = build_product_class
      stub_const("Product", product_class)

      relation = described_class.new(product_class)
      result = relation.select(:id, :title)

      expect(result).to be_a(described_class)
    end
  end

  describe "#limit" do
    it "returns a new relation with a limit applied" do
      product_class = build_product_class

      relation = described_class.new(product_class)
      result = relation.limit(10)

      expect(result).to be_a(described_class)
      expect(result.total_limit).to eq(10)
    end
  end

  describe "chaining operations" do
    it "allows chaining includes and where" do
      customer_class = build_customer_class(with_orders: true)
      stub_const("Customer", customer_class)
      stub_const("Order", build_order_class)

      relation = described_class.new(customer_class)
      result = relation.includes(:orders).where(email: "test@example.com")

      expect(result).to be_a(described_class)
      expect(result.included_connections).to include(:orders)
      expect(result.conditions).to eq(email: "test@example.com")
    end

    it "allows chaining where and includes in any order" do
      customer_class = build_customer_class(with_orders: true)
      stub_const("Customer", customer_class)
      stub_const("Order", build_order_class)

      relation = described_class.new(customer_class)
      result = relation.where(email: "test@example.com").includes(:orders)

      expect(result).to be_a(described_class)
      expect(result.included_connections).to include(:orders)
      expect(result.conditions).to eq(email: "test@example.com")
    end

    it "allows chaining includes, where, and limit" do
      customer_class = build_customer_class(with_orders: true)
      stub_const("Customer", customer_class)
      stub_const("Order", build_order_class)

      relation = described_class.new(customer_class)
      result = relation.includes(:orders).where(country: "Canada").limit(50)

      expect(result).to be_a(described_class)
      expect(result.included_connections).to include(:orders)
      expect(result.conditions).to eq(country: "Canada")
      expect(result.total_limit).to eq(50)
    end

    it "preserves included connections when chaining select" do
      product_class = build_product_class(with_variants: true)
      stub_const("Product", product_class)
      stub_const("ProductVariant", build_product_variant_class)

      relation = described_class.new(product_class, included_connections: [:variants])
      result = relation.select(:id, :title)

      expect(result).to be_a(described_class)
      expect(result.included_connections).to include(:variants)
    end
  end

  describe "consistent interface from model class" do
    it "Customer.includes returns a Relation" do
      customer_class = build_customer_class(with_orders: true)
      stub_const("Customer", customer_class)
      stub_const("Order", build_order_class)

      result = customer_class.includes(:orders)

      expect(result).to be_a(described_class)
    end

    it "Customer.where returns a Relation" do
      customer_class = build_customer_class
      stub_const("Customer", customer_class)

      result = customer_class.where(email: "test@example.com")

      expect(result).to be_a(described_class)
    end

    it "Customer.select returns a Relation" do
      customer_class = build_customer_class
      stub_const("Customer", customer_class)

      result = customer_class.select(:id, :email)

      expect(result).to be_a(described_class)
    end

    it "Customer.includes.find_by works" do
      customer_class = build_customer_class(with_orders: true)
      stub_const("Customer", customer_class)
      stub_const("Order", build_order_class)
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      allow(mock_client).to receive(:execute).and_return({ "data" => { "customers" => { "edges" => [] } } })
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }

      result = customer_class.includes(:orders).find_by(email: "test@example.com")

      expect(result).to be_nil
    end

    it "Customer.includes.where.first works" do
      customer_class = build_customer_class(with_orders: true)
      stub_const("Customer", customer_class)
      stub_const("Order", build_order_class)
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      allow(mock_client).to receive(:execute).and_return({ "data" => { "customers" => { "edges" => [] } } })
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }

      result = customer_class.includes(:orders).where(country: "Canada").first

      expect(result).to be_nil
    end
  end

  describe "#inspect" do
    it "returns a readable representation" do
      product_class = build_product_class(with_variants: true)
      stub_const("Product", product_class)
      stub_const("ProductVariant", build_product_variant_class)

      relation = product_class.includes(:variants).where(title: "Test").limit(10)

      expect(relation.inspect).to include("Product")
      expect(relation.inspect).to include("variants")
      expect(relation.inspect).to include("limit(10)")
    end
  end
end
