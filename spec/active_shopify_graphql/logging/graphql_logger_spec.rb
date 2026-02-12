# frozen_string_literal: true

RSpec.describe ActiveShopifyGraphQL::Logging::GraphqlLogger do
  after do
    ActiveShopifyGraphQL::Logging::GraphqlRuntime.reset_runtime
    ActiveShopifyGraphQL::Logging::GraphqlRuntime.reset_cost
  end

  describe ".log" do
    it "tracks runtime in GraphqlRuntime" do
      described_class.log(query: "query { shop { name } }", duration_ms: 45.2, cost: { "requestedQueryCost" => 10 }, variables: {})
      expect(ActiveShopifyGraphQL::Logging::GraphqlRuntime.runtime).to eq(45.2)
      expect(ActiveShopifyGraphQL::Logging::GraphqlRuntime.cost).to eq(10)
    end

    it "handles nil cost gracefully" do
      described_class.log(query: "query { shop { name } }", duration_ms: 30.0, cost: nil, variables: {})
      expect(ActiveShopifyGraphQL::Logging::GraphqlRuntime.runtime).to eq(30.0)
      expect(ActiveShopifyGraphQL::Logging::GraphqlRuntime.cost).to eq(0)
    end

    it "accumulates across multiple calls" do
      described_class.log(query: "query { shop { name } }", duration_ms: 20.0, cost: { "requestedQueryCost" => 5 }, variables: {})
      described_class.log(query: "mutation { x }", duration_ms: 25.0, cost: { "requestedQueryCost" => 15 }, variables: {})
      expect(ActiveShopifyGraphQL::Logging::GraphqlRuntime.runtime).to eq(45.0)
      expect(ActiveShopifyGraphQL::Logging::GraphqlRuntime.cost).to eq(20)
    end
  end

  describe "graphql_color" do
    subject(:logger) { described_class.new }

    it "returns BLUE for queries" do
      expect(logger.send(:graphql_color, "query { shop { name } }")).to eq(described_class::BLUE)
    end

    it "returns GREEN for mutations" do
      expect(logger.send(:graphql_color, "mutation { createProduct }")).to eq(described_class::GREEN)
    end

    it "returns CYAN for subscriptions" do
      expect(logger.send(:graphql_color, "subscription { orderCreated }")).to eq(described_class::CYAN)
    end

    it "returns MAGENTA for fragments and other queries" do
      expect(logger.send(:graphql_color, "{ shop { name } }")).to eq(described_class::MAGENTA)
    end
  end
end
