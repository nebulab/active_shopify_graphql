# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::IncludesScope do
  before do
    mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
    allow(mock_client).to receive(:execute).and_return(
      { "data" => {} }
    )
    ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
  end

  describe "#initialize" do
    it "stores the model class and included connections" do
      product_class = build_product_class(with_variants: true)
      included_connections = [:variants]

      scope = described_class.new(product_class, included_connections)

      expect(scope.model_class).to eq(product_class)
      expect(scope.included_connections).to eq([:variants])
    end

    it "accepts multiple included connections" do
      customer_class = build_customer_class(with_orders: true, with_addresses: true)
      included_connections = %i[orders addresses]

      scope = described_class.new(customer_class, included_connections)

      expect(scope.model_class).to eq(customer_class)
      expect(scope.included_connections).to eq(%i[orders addresses])
    end
  end

  describe "#find" do
    it "uses a loader with included connections" do
      product_class = build_product_class(with_variants: true)
      variant_class = build_product_variant_class
      stub_const("Product", product_class)
      stub_const("ProductVariant", variant_class)

      scope = described_class.new(product_class, [:variants])
      loader = scope.send(:loader_proxy).loader

      expect(loader).to be_a(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      expect(loader.instance_variable_get(:@included_connections)).to eq([:variants])
    end

    it "memoizes the loader proxy instance" do
      product_class = build_product_class(with_variants: true)
      stub_const("Product", product_class)

      scope = described_class.new(product_class, [:variants])
      proxy1 = scope.send(:loader_proxy)
      proxy2 = scope.send(:loader_proxy)

      expect(proxy1).to be(proxy2)
    end
  end

  describe "#where" do
    it "returns a QueryScope with custom loader containing included connections" do
      product_class = build_product_class(with_variants: true)
      stub_const("Product", product_class)

      scope = described_class.new(product_class, [:variants])
      result = scope.where(title: "test")

      expect(result).to be_a(ActiveShopifyGraphQL::QueryScope)
      expect(result.instance_variable_get(:@model_class)).to eq(product_class)
      expect(result.instance_variable_get(:@conditions)).to eq(title: "test")
      loader = result.send(:loader)
      expect(loader).to be_a(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      expect(loader.instance_variable_get(:@included_connections)).to eq([:variants])
    end

    it "supports string conditions with parameter binding" do
      customer_class = build_customer_class(with_orders: true)
      stub_const("Customer", customer_class)

      scope = described_class.new(customer_class, [:orders])
      result = scope.where("email:?", "*@example.com")

      expect(result).to be_a(ActiveShopifyGraphQL::QueryScope)
      expect(result.instance_variable_get(:@conditions)).to eq(["email:?", "*@example.com"])
      loader = result.send(:loader)
      expect(loader).to be_a(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
    end

    it "supports string conditions with named parameter binding" do
      customer_class = build_customer_class(with_orders: true)
      stub_const("Customer", customer_class)

      scope = described_class.new(customer_class, [:orders])
      result = scope.where("email::domain", domain: "*@example.com")

      expect(result).to be_a(ActiveShopifyGraphQL::QueryScope)
      expect(result.instance_variable_get(:@conditions)).to eq(["email::domain", { domain: "*@example.com" }])
    end
  end

  describe "#select" do
    it "creates a new scope with select applied and maintains included connections" do
      product_class = build_product_class(with_variants: true)
      stub_const("Product", product_class)
      selected_model = instance_double("SelectedProduct")
      allow(product_class).to receive(:select).with(:id, :title).and_return(selected_model)

      scope = described_class.new(product_class, [:variants])
      result = scope.select(:id, :title)

      expect(product_class).to have_received(:select).with(:id, :title)
      expect(result).to be_a(described_class)
      expect(result.model_class).to eq(selected_model)
      expect(result.included_connections).to eq([:variants])
    end

    it "chains multiple select calls correctly" do
      product_class = build_product_class(with_variants: true)
      stub_const("Product", product_class)
      first_selected = instance_double("FirstSelected")
      second_selected = instance_double("SecondSelected")
      allow(product_class).to receive(:select).with(:id).and_return(first_selected)
      allow(first_selected).to receive(:select).with(:title).and_return(second_selected)

      scope = described_class.new(product_class, [:variants])
      result = scope.select(:id).select(:title)

      expect(result).to be_a(described_class)
      expect(result.model_class).to eq(second_selected)
      expect(result.included_connections).to eq([:variants])
    end
  end

  describe "#includes" do
    it "returns a new scope with combined included connections" do
      customer_class = build_customer_class(with_orders: true, with_addresses: true)
      stub_const("Customer", customer_class)
      new_scope = instance_double(described_class)
      allow(customer_class).to receive(:includes).with(:orders, :addresses).and_return(new_scope)

      scope = described_class.new(customer_class, [:orders])
      result = scope.includes(:addresses)

      expect(customer_class).to have_received(:includes).with(:orders, :addresses)
      expect(result).to eq(new_scope)
    end

    it "deduplicates connection names when chaining" do
      customer_class = build_customer_class(with_orders: true, with_addresses: true)
      stub_const("Customer", customer_class)
      new_scope = instance_double(described_class)
      allow(customer_class).to receive(:includes).with(:orders).and_return(new_scope)

      scope = described_class.new(customer_class, [:orders])
      result = scope.includes(:orders)

      expect(customer_class).to have_received(:includes).with(:orders)
      expect(result).to eq(new_scope)
    end

    it "accepts multiple connection names" do
      customer_class = build_customer_class(with_orders: true, with_addresses: true)
      stub_const("Customer", customer_class)
      new_scope = instance_double(described_class)
      allow(customer_class).to receive(:includes).with(:orders, :addresses).and_return(new_scope)

      scope = described_class.new(customer_class, [:orders])
      scope.includes(:addresses)

      expect(customer_class).to have_received(:includes).with(:orders, :addresses)
    end
  end

  describe "chaining operations" do
    it "allows chaining select and maintains included connections" do
      product_class = build_product_class(with_variants: true)
      variant_class = build_product_variant_class
      stub_const("Product", product_class)
      stub_const("ProductVariant", variant_class)

      scope = described_class.new(product_class, [:variants])
      chained_scope = scope.select(:id, :title)

      expect(chained_scope).to be_a(described_class)
      expect(chained_scope.included_connections).to eq([:variants])
      # The model_class should be a selected scope (anonymous class)
      expect(chained_scope.model_class).not_to eq(product_class)
    end

    it "allows chaining select and where" do
      product_class = build_product_class(with_variants: true)
      stub_const("Product", product_class)
      selected_model = product_class.select(:id)
      allow(product_class).to receive(:select).with(:id).and_return(selected_model)
      allow(selected_model).to receive(:where).and_return([])

      scope = described_class.new(product_class, [:variants])
      chained_scope = scope.select(:id)
      chained_scope.where(query: "test")

      expect(product_class).to have_received(:select).with(:id)
      expect(chained_scope).to be_a(described_class)
      expect(chained_scope.model_class).to eq(selected_model)
      expect(chained_scope.included_connections).to eq([:variants])
    end

    it "preserves included connections through select chains" do
      customer_class = build_customer_class(with_orders: true, with_addresses: true)
      stub_const("Customer", customer_class)
      first_select_model = instance_double("FirstSelectedCustomer")
      second_select_model = instance_double("SecondSelectedCustomer")
      allow(customer_class).to receive(:select).with(:id).and_return(first_select_model)
      allow(first_select_model).to receive(:select).with(:email).and_return(second_select_model)

      scope = described_class.new(customer_class, %i[orders addresses])
      result = scope.select(:id).select(:email)

      expect(result).to be_a(described_class)
      expect(result.model_class).to eq(second_select_model)
      expect(result.included_connections).to eq(%i[orders addresses])
    end
  end

  describe "integration with connections" do
    it "passes included connections to the loader for eager loading" do
      product_class = build_product_class(with_variants: true)
      variant_class = build_product_variant_class
      stub_const("Product", product_class)
      stub_const("ProductVariant", variant_class)

      scope = described_class.new(product_class, [:variants])
      loader = scope.send(:loader_proxy).loader

      expect(loader).to be_a(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      expect(loader.instance_variable_get(:@included_connections)).to eq([:variants])
    end
  end
end
