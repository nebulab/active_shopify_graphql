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
    it "delegates to model class with custom loader containing included connections" do
      product_class = build_product_class(with_variants: true)
      stub_const("Product", product_class)
      allow(product_class).to receive(:find).and_return(product_class.new(id: "gid://shopify/Product/123"))

      scope = described_class.new(product_class, [:variants])
      scope.find("gid://shopify/Product/123")

      expect(product_class).to have_received(:find) do |id, **options|
        expect(id).to eq("gid://shopify/Product/123")
        expect(options[:loader]).to be_a(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
        expect(options[:loader].instance_variable_get(:@included_connections)).to eq([:variants])
      end
    end

    it "accepts optional loader parameter and uses it instead" do
      product_class = build_product_class(with_variants: true)
      stub_const("Product", product_class)
      custom_loader = ActiveShopifyGraphQL::Loaders::AdminApiLoader.new(product_class)
      allow(product_class).to receive(:find).and_return(product_class.new(id: "gid://shopify/Product/123"))

      scope = described_class.new(product_class, [:variants])
      scope.find("gid://shopify/Product/123", loader: custom_loader)

      expect(product_class).to have_received(:find).with("gid://shopify/Product/123", loader: custom_loader)
    end

    it "memoizes the default loader instance" do
      product_class = build_product_class(with_variants: true)
      stub_const("Product", product_class)

      scope = described_class.new(product_class, [:variants])
      loader1 = scope.send(:default_loader)
      loader2 = scope.send(:default_loader)

      expect(loader1).to be(loader2)
      expect(loader1.instance_variable_get(:@included_connections)).to eq([:variants])
    end
  end

  describe "#where" do
    it "delegates to model class with custom loader containing included connections" do
      product_class = build_product_class(with_variants: true)
      stub_const("Product", product_class)
      allow(product_class).to receive(:where).and_return([])

      scope = described_class.new(product_class, [:variants])
      scope.where(query: "test")

      expect(product_class).to have_received(:where) do |**options|
        expect(options[:query]).to eq("test")
        expect(options[:loader]).to be_a(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
        expect(options[:loader].instance_variable_get(:@included_connections)).to eq([:variants])
      end
    end

    it "accepts optional loader parameter and uses it instead" do
      product_class = build_product_class(with_variants: true)
      stub_const("Product", product_class)
      custom_loader = ActiveShopifyGraphQL::Loaders::AdminApiLoader.new(product_class)
      allow(product_class).to receive(:where).and_return([])

      scope = described_class.new(product_class, [:variants])
      scope.where(query: "test", loader: custom_loader)

      expect(product_class).to have_received(:where).with(query: "test", loader: custom_loader)
    end

    it "passes through arguments and options correctly" do
      customer_class = build_customer_class(with_orders: true)
      stub_const("Customer", customer_class)
      allow(customer_class).to receive(:where).and_return([])

      scope = described_class.new(customer_class, [:orders])
      scope.where("email:*@example.com", query: "email:*@example.com", first: 10)

      expect(customer_class).to have_received(:where) do |*args, **options|
        expect(args).to eq(["email:*@example.com"])
        expect(options[:query]).to eq("email:*@example.com")
        expect(options[:first]).to eq(10)
        expect(options[:loader]).to be_a(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      end
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
    it "allows chaining select and find" do
      product_class = build_product_class(with_variants: true)
      stub_const("Product", product_class)
      selected_model = product_class.select(:id, :title)
      allow(product_class).to receive(:select).with(:id, :title).and_return(selected_model)
      allow(selected_model).to receive(:find).and_return(product_class.new(id: "gid://shopify/Product/123"))

      scope = described_class.new(product_class, [:variants])
      chained_scope = scope.select(:id, :title)
      chained_scope.find("gid://shopify/Product/123")

      expect(product_class).to have_received(:select).with(:id, :title)
      expect(chained_scope).to be_a(described_class)
      expect(chained_scope.model_class).to eq(selected_model)
      expect(chained_scope.included_connections).to eq([:variants])
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
      stub_const("Product", product_class)
      allow(product_class).to receive(:find).and_return(product_class.new(id: "gid://shopify/Product/123"))

      scope = described_class.new(product_class, [:variants])
      scope.find("gid://shopify/Product/123")

      expect(product_class).to have_received(:find) do |_id, **options|
        loader = options[:loader]
        expect(loader).to be_a(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
        # The loader should have included_connections configured
        expect(loader.instance_variable_get(:@included_connections)).to eq([:variants])
      end
    end
  end
end
