# frozen_string_literal: true

require "spec_helper"
require "active_shopify_graphql/testing"

RSpec.describe "Testing Integration" do
  include ActiveShopifyGraphQL::Testing::TestHelpers

  customer_class = Class.new(ActiveShopifyGraphQL::Model) do
    attribute :id
    attribute :email
    attribute :display_name, path: "displayName"
    attribute :status
    attribute :total_spent, path: "amountSpent.amount"

    define_singleton_method(:name) { "Customer" }
    define_singleton_method(:graphql_type) { "Customer" }
  end

  before(:each) do
    ActiveShopifyGraphQL::Testing.enable!
    stub_const("Customer", customer_class)
  end

  after(:each) do
    ActiveShopifyGraphQL::Testing.disable!
  end

  describe "Model.find" do
    it "finds a record by numeric ID" do
      create_graphql_record(Customer, id: 123, email: "test@example.com", display_name: "John Doe")

      customer = Customer.find(123)

      expect(customer).to be_a(Customer)
      expect(customer.id).to eq("gid://shopify/Customer/123")
      expect(customer.email).to eq("test@example.com")
      expect(customer.display_name).to eq("John Doe")
    end

    it "finds a record by GID" do
      create_graphql_record(Customer, id: "gid://shopify/Customer/456", email: "other@example.com")

      customer = Customer.find("gid://shopify/Customer/456")

      expect(customer.email).to eq("other@example.com")
    end

    it "returns nil when record not found" do
      customer = Customer.find(999)

      expect(customer).to be_nil
    end
  end

  describe "Model.where" do
    it "filters records by equality" do
      create_graphql_records(Customer, [
                               { id: 1, email: "a@test.com", status: "active" },
                               { id: 2, email: "b@test.com", status: "inactive" },
                               { id: 3, email: "c@test.com", status: "active" }
                             ])

      customers = Customer.where(status: "active").to_a

      expect(customers.size).to eq(2)
      expect(customers.map(&:email)).to contain_exactly("a@test.com", "c@test.com")
    end

    it "filters with array condition (OR)" do
      create_graphql_records(Customer, [
                               { id: 1, status: "active" },
                               { id: 2, status: "pending" },
                               { id: 3, status: "inactive" }
                             ])

      customers = Customer.where(status: %w[active pending]).to_a

      expect(customers.size).to eq(2)
    end

    it "filters with range conditions" do
      create_graphql_records(Customer, [
                               { id: 1, total_spent: 50 },
                               { id: 2, total_spent: 100 },
                               { id: 3, total_spent: 200 }
                             ])

      high_spenders = Customer.where(total_spent: { gte: 100 }).to_a

      expect(high_spenders.size).to eq(2)
    end

    it "combines multiple conditions with AND" do
      create_graphql_records(Customer, [
                               { id: 1, status: "active", total_spent: 50 },
                               { id: 2, status: "active", total_spent: 150 },
                               { id: 3, status: "inactive", total_spent: 200 }
                             ])

      customers = Customer.where(status: "active", total_spent: { gte: 100 }).to_a

      expect(customers.size).to eq(1)
      expect(customers.first.id).to eq("gid://shopify/Customer/2")
    end

    it "returns empty array when no records match" do
      create_graphql_record(Customer, id: 1, status: "active")

      customers = Customer.where(status: "nonexistent").to_a

      expect(customers).to eq([])
    end
  end

  describe "pagination" do
    it "respects first/limit" do
      create_graphql_records(Customer, [
                               { id: 1, email: "a@test.com" },
                               { id: 2, email: "b@test.com" },
                               { id: 3, email: "c@test.com" },
                               { id: 4, email: "d@test.com" },
                               { id: 5, email: "e@test.com" }
                             ])

      result = Customer.where({}).first(2)

      expect(result.size).to eq(2)
      expect(result.has_next_page?).to be(true)
    end
  end

  describe "loader class tracking" do
    it "tracks when admin API loader was requested" do
      create_graphql_record(Customer, id: 1, email: "test@example.com")

      Customer.with_admin_api.find(1)

      expect(requested_loader_class).to eq(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
    end

    it "tracks when customer account API loader was requested" do
      create_graphql_record(Customer, id: 1, email: "test@example.com")

      Customer.with_customer_account_api("token").find(1)

      expect(requested_loader_class).to eq(ActiveShopifyGraphQL::Loaders::CustomerAccountApiLoader)
    end
  end

  describe "test isolation" do
    it "clears registry between tests (test 1)" do
      create_graphql_record(Customer, id: 1, email: "first@test.com")

      expect(graphql_registry_count).to eq(1)
    end

    it "clears registry between tests (test 2)" do
      # Registry should be empty after disable! in after(:each)
      expect(graphql_registry_count).to eq(0)

      create_graphql_record(Customer, id: 2, email: "second@test.com")
      expect(graphql_registry_count).to eq(1)
    end
  end
end
