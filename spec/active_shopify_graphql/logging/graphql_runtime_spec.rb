# frozen_string_literal: true

RSpec.describe ActiveShopifyGraphQL::Logging::GraphqlRuntime do
  after do
    described_class.reset_runtime
    described_class.reset_cost
  end

  describe ".runtime" do
    it "defaults to 0" do
      expect(described_class.runtime).to eq(0)
    end

    it "can be set and retrieved" do
      described_class.runtime = 42.5
      expect(described_class.runtime).to eq(42.5)
    end
  end

  describe ".reset_runtime" do
    it "returns accumulated runtime and resets to 0" do
      described_class.runtime = 100.5
      result = described_class.reset_runtime
      expect(result).to eq(100.5)
      expect(described_class.runtime).to eq(0)
    end
  end

  describe ".cost" do
    it "defaults to 0" do
      expect(described_class.cost).to eq(0)
    end

    it "can be set and retrieved" do
      described_class.cost = 38
      expect(described_class.cost).to eq(38)
    end
  end

  describe ".reset_cost" do
    it "returns accumulated cost and resets to 0" do
      described_class.cost = 75
      result = described_class.reset_cost
      expect(result).to eq(75)
      expect(described_class.cost).to eq(0)
    end
  end

  describe ".add" do
    it "accumulates runtime and cost" do
      described_class.add(duration_ms: 10.5, cost: 5)
      described_class.add(duration_ms: 20.0, cost: 10)
      expect(described_class.runtime).to eq(30.5)
      expect(described_class.cost).to eq(15)
    end

    it "handles nil cost gracefully" do
      described_class.add(duration_ms: 10.5, cost: nil)
      expect(described_class.runtime).to eq(10.5)
      expect(described_class.cost).to eq(0)
    end
  end
end
