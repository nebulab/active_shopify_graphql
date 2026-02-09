# frozen_string_literal: true

require "spec_helper"
require "active_shopify_graphql/testing"

RSpec.describe ActiveShopifyGraphQL::Testing::TestLoader do
  described_class = ActiveShopifyGraphQL::Testing::TestLoader
  registry = ActiveShopifyGraphQL::Testing::TestRegistry

  customer_class = Class.new(ActiveShopifyGraphQL::Model) do
    attribute :id
    attribute :email
    attribute :status
    attribute :created_at

    define_singleton_method(:name) { "Customer" }
    define_singleton_method(:graphql_type) { "Customer" }
  end

  after(:each) do
    registry.clear!
    described_class.last_requested_loader_class = nil
  end

  describe "#load_attributes" do
    it "loads attributes from the registry by numeric ID" do
      registry.register(customer_class, id: 123, email: "test@example.com", status: "active")
      loader = described_class.new(customer_class)

      attributes = loader.load_attributes(123)

      expect(attributes[:id]).to eq("gid://shopify/Customer/123")
      expect(attributes[:email]).to eq("test@example.com")
      expect(attributes[:status]).to eq("active")
    end

    it "loads attributes from the registry by GID" do
      registry.register(customer_class, id: "gid://shopify/Customer/456", email: "test@example.com")
      loader = described_class.new(customer_class)

      attributes = loader.load_attributes("gid://shopify/Customer/456")

      expect(attributes[:email]).to eq("test@example.com")
    end

    it "returns nil when record not found" do
      loader = described_class.new(customer_class)

      attributes = loader.load_attributes(999)

      expect(attributes).to be_nil
    end

    it "excludes internal metadata keys from attributes" do
      registry.register(customer_class, id: 123, email: "test@example.com")
      loader = described_class.new(customer_class)

      attributes = loader.load_attributes(123)

      expect(attributes.keys).not_to include(:_model_class, :_gid)
    end

    it "filters to selected attributes when specified" do
      registry.register(customer_class, id: 123, email: "test@example.com", status: "active")
      loader = described_class.new(customer_class, selected_attributes: [:email])

      attributes = loader.load_attributes(123)

      expect(attributes.keys).to contain_exactly(:id, :email)
      expect(attributes[:status]).to be_nil
    end
  end

  describe "#load_paginated_collection" do
    it "returns all matching records" do
      registry.register(customer_class, id: 1, email: "a@test.com", status: "active")
      registry.register(customer_class, id: 2, email: "b@test.com", status: "inactive")
      registry.register(customer_class, id: 3, email: "c@test.com", status: "active")

      loader = described_class.new(customer_class)
      scope = instance_double(ActiveShopifyGraphQL::Query::Scope)

      result = loader.load_paginated_collection(
        conditions: { status: "active" },
        per_page: 10,
        query_scope: scope
      )

      expect(result).to be_a(ActiveShopifyGraphQL::Response::PaginatedResult)
      expect(result.size).to eq(2)
    end

    it "respects per_page limit" do
      5.times { |i| registry.register(customer_class, id: i + 1, email: "#{i}@test.com") }

      loader = described_class.new(customer_class)
      scope = instance_double(ActiveShopifyGraphQL::Query::Scope)

      result = loader.load_paginated_collection(
        conditions: {},
        per_page: 2,
        query_scope: scope
      )

      expect(result.size).to eq(2)
      expect(result.has_next_page?).to be(true)
    end

    it "returns empty result when no records match" do
      loader = described_class.new(customer_class)
      scope = instance_double(ActiveShopifyGraphQL::Query::Scope)

      result = loader.load_paginated_collection(
        conditions: { status: "nonexistent" },
        per_page: 10,
        query_scope: scope
      )

      expect(result.size).to eq(0)
      expect(result.empty?).to be(true)
    end

    it "raises error for non-hash conditions" do
      loader = described_class.new(customer_class)
      scope = instance_double(ActiveShopifyGraphQL::Query::Scope)

      expect do
        loader.load_paginated_collection(
          conditions: "email:test@example.com",
          per_page: 10,
          query_scope: scope
        )
      end.to raise_error(ArgumentError, /TestLoader only supports hash conditions/)
    end
  end

  describe "#perform_graphql_query" do
    it "raises NotImplementedError to prevent network calls" do
      loader = described_class.new(customer_class)

      expect { loader.perform_graphql_query("query { }") }
        .to raise_error(NotImplementedError, /TestLoader does not perform network requests/)
    end
  end

  describe "original loader class tracking" do
    it "tracks the original loader class when provided" do
      admin_loader_class = ActiveShopifyGraphQL::Loaders::AdminApiLoader
      loader = described_class.new(customer_class, original_loader_class: admin_loader_class)

      expect(described_class.last_requested_loader_class).to eq(admin_loader_class)
      expect(loader.instance_variable_get(:@original_loader_class)).to eq(admin_loader_class)
    end
  end
end
