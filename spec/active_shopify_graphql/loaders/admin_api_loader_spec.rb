# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Loaders::AdminApiLoader do
  describe "#perform_graphql_query" do
    it "executes query using configured admin_api_client" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      model_class = build_customer_class
      loader = described_class.new(model_class)
      expected_response = { "data" => { "customer" => { "id" => "123" } } }
      expect(mock_client).to receive(:execute).with("query { customer }").and_return(expected_response)

      result = loader.perform_graphql_query("query { customer }")

      expect(result).to eq(expected_response)
    end

    it "passes variables to client execute" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      model_class = build_customer_class
      loader = described_class.new(model_class)
      expect(mock_client).to receive(:execute).with("query { customer(id: $id) }", id: "123").and_return({})

      loader.perform_graphql_query("query { customer(id: $id) }", id: "123")
    end
  end
end
