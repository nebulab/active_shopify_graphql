# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "CustomerAccountApiLoader graphql_type handling" do
  let(:customer_class) do
    Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type "Customer"

      attribute :id, type: :string
      attribute :name, path: "displayName", type: :string

      def self.name
        "Customer"
      end

      def self.model_name
        ActiveModel::Name.new(self, nil, "Customer")
      end
    end
  end

  describe "graphql_type integration" do
    it "gets graphql_type from model class when creating loader" do
      loader = ActiveShopifyGraphQL::CustomerAccountApiLoader.new(customer_class, "fake_token")

      expect(loader.graphql_type).to eq("Customer")
    end

    it "uses model's graphql_type in graphql_query method" do
      loader = ActiveShopifyGraphQL::CustomerAccountApiLoader.new(customer_class, "fake_token")

      # Mock the fragment method since we're not testing fragment generation
      allow(loader).to receive(:fragment).and_return("fragment CustomerFragment on Customer { id }")

      query = loader.graphql_query

      expect(query).to include("query getCurrentCustomer")
      expect(query).to include("customer {")
    end

    it "uses model's graphql_type in load_attributes method" do
      loader = ActiveShopifyGraphQL::CustomerAccountApiLoader.new(customer_class, "fake_token")

      # Mock the execute_graphql_query to avoid actual API calls
      allow(loader).to receive(:execute_graphql_query).and_return({ "customer" => { "id" => "123", "displayName" => "Test" } })
      allow(loader).to receive(:map_response_to_attributes).and_return({ id: "123", name: "Test" })

      # This should not raise an error about graphql_type
      expect { loader.load_attributes }.not_to raise_error
    end
  end
end
