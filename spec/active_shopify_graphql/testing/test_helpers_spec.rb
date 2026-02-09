# frozen_string_literal: true

require "spec_helper"
require "active_shopify_graphql/testing"

RSpec.describe ActiveShopifyGraphQL::Testing::TestHelpers do
  test_object = Object.new.tap { |o| o.extend(ActiveShopifyGraphQL::Testing::TestHelpers) }

  customer_class = Class.new(ActiveShopifyGraphQL::Model) do
    attribute :id
    attribute :email
    attribute :status

    define_singleton_method(:name) { "Customer" }
    define_singleton_method(:graphql_type) { "Customer" }
  end

  after(:each) do
    ActiveShopifyGraphQL::Testing::TestRegistry.clear!
    ActiveShopifyGraphQL::Testing::TestLoader.last_requested_loader_class = nil
  end

  describe "#create_graphql_record" do
    it "registers a single record in the registry" do
      record = test_object.create_graphql_record(customer_class, id: 123, email: "test@example.com")

      expect(record[:id]).to eq("gid://shopify/Customer/123")
      expect(record[:email]).to eq("test@example.com")
      expect(test_object.graphql_registry_count).to eq(1)
    end
  end

  describe "#create_graphql_records" do
    it "registers multiple records in the registry" do
      records = test_object.create_graphql_records(customer_class, [
                                                     { id: 1, email: "a@test.com" },
                                                     { id: 2, email: "b@test.com" }
                                                   ])

      expect(records.size).to eq(2)
      expect(test_object.graphql_registry_count).to eq(2)
    end
  end

  describe "#clear_graphql_records!" do
    it "clears all records from the registry" do
      test_object.create_graphql_record(customer_class, id: 1, email: "test@example.com")
      expect(test_object.graphql_registry_empty?).to be(false)

      test_object.clear_graphql_records!

      expect(test_object.graphql_registry_empty?).to be(true)
    end
  end

  describe "#requested_loader_class" do
    it "returns the last requested loader class" do
      admin_loader = ActiveShopifyGraphQL::Loaders::AdminApiLoader
      ActiveShopifyGraphQL::Testing::TestLoader.last_requested_loader_class = admin_loader

      expect(test_object.requested_loader_class).to eq(admin_loader)
    end

    it "returns nil when no loader has been requested" do
      expect(test_object.requested_loader_class).to be_nil
    end
  end

  describe "#graphql_registry_empty?" do
    it "returns true when registry is empty" do
      expect(test_object.graphql_registry_empty?).to be(true)
    end

    it "returns false when registry has records" do
      test_object.create_graphql_record(customer_class, id: 1)

      expect(test_object.graphql_registry_empty?).to be(false)
    end
  end

  describe "#graphql_registry_count" do
    it "returns the count of records in the registry" do
      expect(test_object.graphql_registry_count).to eq(0)

      test_object.create_graphql_record(customer_class, id: 1)
      test_object.create_graphql_record(customer_class, id: 2)

      expect(test_object.graphql_registry_count).to eq(2)
    end
  end
end
