# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Loaders::AdminApiLoader do
  describe "#perform_graphql_query" do
    it "executes query using configured admin_api_adapter" do
      expected_response = { "customer" => { "id" => "123" } }
      mock_adapter = instance_double(ActiveShopifyGraphQL::Adapters::Base)
      allow(mock_adapter).to receive(:execute).and_return(expected_response)
      ActiveShopifyGraphQL.configure { |c| c.admin_api_adapter = mock_adapter }
      model_class = build_customer_class
      loader = described_class.new(model_class)

      result = loader.perform_graphql_query("query { customer }")

      expect(result).to eq(expected_response)
      expect(mock_adapter).to have_received(:execute).with("query { customer }")
    end

    it "passes variables to adapter" do
      expected_response = { "customer" => { "id" => "123" } }
      mock_adapter = instance_double(ActiveShopifyGraphQL::Adapters::Base)
      allow(mock_adapter).to receive(:execute).and_return(expected_response)
      ActiveShopifyGraphQL.configure { |c| c.admin_api_adapter = mock_adapter }
      model_class = build_customer_class
      loader = described_class.new(model_class)

      result = loader.perform_graphql_query("query { customer(id: $id) }", id: "123")

      expect(result).to eq(expected_response)
      expect(mock_adapter).to have_received(:execute).with("query { customer(id: $id) }", id: "123")
    end

    it "maintains backward compatibility with admin_api_executor" do
      expected_response = { "data" => { "customer" => { "id" => "123" } } }
      mock_executor = ->(query, **_variables) { expected_response if query == "query { customer }" }
      ActiveShopifyGraphQL.configure do |c|
        c.admin_api_adapter = nil
        c.admin_api_executor = mock_executor
      end
      model_class = build_customer_class
      loader = described_class.new(model_class)

      result = loader.perform_graphql_query("query { customer }")

      expect(result).to eq(expected_response)
    end

    it "raises error when neither adapter nor executor is configured" do
      ActiveShopifyGraphQL.configure do |c|
        c.admin_api_adapter = nil
        c.admin_api_executor = nil
      end
      model_class = build_customer_class
      loader = described_class.new(model_class)

      expect { loader.perform_graphql_query("query { customer }") }
        .to raise_error(ActiveShopifyGraphQL::Error, /Admin API adapter not configured/)
    end
  end
end
