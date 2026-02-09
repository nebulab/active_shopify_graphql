# frozen_string_literal: true

require "spec_helper"
require "active_shopify_graphql/testing"

RSpec.describe ActiveShopifyGraphQL::Testing do
  after(:each) do
    described_class.disable!
  end

  describe ".enable!" do
    it "enables test mode in configuration" do
      described_class.enable!

      expect(ActiveShopifyGraphQL.configuration.test_mode?).to be(true)
    end
  end

  describe ".disable!" do
    it "disables test mode in configuration" do
      described_class.enable!
      described_class.disable!

      expect(ActiveShopifyGraphQL.configuration.test_mode?).to be(false)
    end

    it "clears the test registry" do
      customer_class = Class.new(ActiveShopifyGraphQL::Model) do
        attribute :id
        define_singleton_method(:name) { "Customer" }
        define_singleton_method(:graphql_type) { "Customer" }
      end

      described_class.enable!
      ActiveShopifyGraphQL::Testing::TestRegistry.register(customer_class, id: 1)
      expect(ActiveShopifyGraphQL::Testing::TestRegistry.count).to eq(1)

      described_class.disable!

      expect(ActiveShopifyGraphQL::Testing::TestRegistry.count).to eq(0)
    end

    it "clears the last requested loader class" do
      ActiveShopifyGraphQL::Testing::TestLoader.last_requested_loader_class = Class.new

      described_class.disable!

      expect(ActiveShopifyGraphQL::Testing::TestLoader.last_requested_loader_class).to be_nil
    end
  end

  describe ".enabled?" do
    it "returns true when test mode is enabled" do
      described_class.enable!

      expect(described_class.enabled?).to be(true)
    end

    it "returns false when test mode is disabled" do
      described_class.disable!

      expect(described_class.enabled?).to be(false)
    end
  end

  describe ".with_test_mode" do
    it "enables test mode for the duration of the block" do
      expect(described_class.enabled?).to be(false)

      was_enabled_in_block = nil
      described_class.with_test_mode do
        was_enabled_in_block = described_class.enabled?
      end

      expect(was_enabled_in_block).to be(true)
      expect(described_class.enabled?).to be(false)
    end

    it "returns the block result" do
      result = described_class.with_test_mode { "test result" }

      expect(result).to eq("test result")
    end

    it "restores previous state even on exception" do
      expect(described_class.enabled?).to be(false)

      expect do
        described_class.with_test_mode { raise "test error" }
      end.to raise_error("test error")

      expect(described_class.enabled?).to be(false)
    end
  end
end
