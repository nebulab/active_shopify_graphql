# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Loaders::AdminApiLoader do
  describe "#perform_graphql_query" do
    it "executes query using configured admin_api_executor" do
      expected_response = { "data" => { "customer" => { "id" => "123" } } }
      mock_executor = ->(query, **_variables) { expected_response if query == "query { customer }" }
      ActiveShopifyGraphQL.configure { |c| c.admin_api_executor = mock_executor }
      model_class = build_customer_class
      loader = described_class.new(model_class)

      result = loader.perform_graphql_query("query { customer }")

      expect(result).to eq(expected_response)
    end

    it "passes variables to executor" do
      received_query = nil
      received_variables = nil
      mock_executor = lambda { |query, **variables|
        received_query = query
        received_variables = variables
        {}
      }
      ActiveShopifyGraphQL.configure { |c| c.admin_api_executor = mock_executor }
      model_class = build_customer_class
      loader = described_class.new(model_class)

      loader.perform_graphql_query("query { customer(id: $id) }", id: "123")

      expect(received_query).to eq("query { customer(id: $id) }")
      expect(received_variables).to eq({ id: "123" })
    end

    it "raises error when admin_api_executor is nil" do
      ActiveShopifyGraphQL.configure { |c| c.admin_api_executor = nil }
      model_class = build_customer_class
      loader = described_class.new(model_class)

      expect { loader.perform_graphql_query("query { customer }") }
        .to raise_error(ActiveShopifyGraphQL::Error, /Admin API executor not configured/)
    end
  end
end
