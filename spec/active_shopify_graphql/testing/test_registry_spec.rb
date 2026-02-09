# frozen_string_literal: true

require "spec_helper"
require "active_shopify_graphql/testing"

RSpec.describe ActiveShopifyGraphQL::Testing::TestRegistry do
  described_class = ActiveShopifyGraphQL::Testing::TestRegistry

  customer_class = Class.new(ActiveShopifyGraphQL::Model) do
    attribute :id
    attribute :email
    attribute :status
    attribute :created_at

    define_singleton_method(:name) { "Customer" }
    define_singleton_method(:graphql_type) { "Customer" }
  end

  after(:each) do
    described_class.clear!
  end

  describe ".register" do
    it "registers a record and normalizes the GID" do
      record = described_class.register(customer_class, id: 123, email: "test@example.com")

      expect(record[:id]).to eq("gid://shopify/Customer/123")
      expect(record[:email]).to eq("test@example.com")
      expect(record[:_model_class]).to eq(customer_class)
    end

    it "preserves existing GID format" do
      record = described_class.register(customer_class, id: "gid://shopify/Customer/456", email: "test@example.com")

      expect(record[:id]).to eq("gid://shopify/Customer/456")
    end

    it "converts string keys to symbols" do
      record = described_class.register(customer_class, "id" => 123, "email" => "test@example.com")

      expect(record[:id]).to eq("gid://shopify/Customer/123")
      expect(record[:email]).to eq("test@example.com")
    end
  end

  describe ".register_many" do
    it "registers multiple records at once" do
      records = described_class.register_many(customer_class, [
                                                { id: 1, email: "a@test.com" },
                                                { id: 2, email: "b@test.com" }
                                              ])

      expect(records.size).to eq(2)
      expect(described_class.count).to eq(2)
    end
  end

  describe ".find_by_gid" do
    it "finds a record by its GID" do
      described_class.register(customer_class, id: 123, email: "test@example.com")

      record = described_class.find_by_gid("gid://shopify/Customer/123")

      expect(record[:email]).to eq("test@example.com")
    end

    it "returns nil for non-existent GID" do
      record = described_class.find_by_gid("gid://shopify/Customer/999")

      expect(record).to be_nil
    end

    it "returns a copy to prevent mutation" do
      described_class.register(customer_class, id: 123, email: "original@example.com")

      record = described_class.find_by_gid("gid://shopify/Customer/123")
      record[:email] = "modified@example.com"

      fresh_record = described_class.find_by_gid("gid://shopify/Customer/123")
      expect(fresh_record[:email]).to eq("original@example.com")
    end
  end

  describe ".find_all" do
    it "returns all records for a model class" do
      described_class.register(customer_class, id: 1, email: "a@test.com")
      described_class.register(customer_class, id: 2, email: "b@test.com")

      records = described_class.find_all(customer_class)

      expect(records.size).to eq(2)
      expect(records.map { |r| r[:email] }).to contain_exactly("a@test.com", "b@test.com")
    end

    it "returns empty array when no records exist" do
      records = described_class.find_all(customer_class)

      expect(records).to eq([])
    end
  end

  describe ".filter" do
    it "filters records by equality condition" do
      described_class.register(customer_class, id: 1, status: "active", email: "a@test.com")
      described_class.register(customer_class, id: 2, status: "inactive", email: "b@test.com")
      described_class.register(customer_class, id: 3, status: "active", email: "c@test.com")

      results = described_class.filter(customer_class, { status: "active" })

      expect(results.size).to eq(2)
      expect(results.map { |r| r[:email] }).to contain_exactly("a@test.com", "c@test.com")
    end

    it "filters by array condition (OR semantics)" do
      described_class.register(customer_class, id: 1, status: "active", email: "a@test.com")
      described_class.register(customer_class, id: 2, status: "inactive", email: "b@test.com")
      described_class.register(customer_class, id: 3, status: "pending", email: "c@test.com")

      results = described_class.filter(customer_class, { status: %w[active pending] })

      expect(results.size).to eq(2)
      expect(results.map { |r| r[:email] }).to contain_exactly("a@test.com", "c@test.com")
    end

    it "returns all records when conditions are empty" do
      described_class.register(customer_class, id: 1, email: "a@test.com")
      described_class.register(customer_class, id: 2, email: "b@test.com")

      results = described_class.filter(customer_class, {})

      expect(results.size).to eq(2)
    end
  end

  describe ".clear!" do
    it "removes all records from the registry" do
      described_class.register(customer_class, id: 1, email: "test@example.com")
      expect(described_class.count).to eq(1)

      described_class.clear!

      expect(described_class.count).to eq(0)
      expect(described_class.empty?).to be(true)
    end
  end
end
