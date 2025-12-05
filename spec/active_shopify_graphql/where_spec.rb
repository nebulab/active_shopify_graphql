# frozen_string_literal: true

RSpec.describe "Where functionality" do
  let(:mock_client) do
    double("GraphQLClient")
  end

  let(:mock_loader) do
    client = mock_client
    Class.new(ActiveShopifyGraphQL::AdminApiLoader) do
      define_method :initialize do
        @client = client
      end

      def fragment
        <<~GRAPHQL
          fragment CustomerFragment on Customer {
            id
            displayName
            defaultEmailAddress {
              emailAddress
            }
            createdAt
          }
        GRAPHQL
      end

      def map_response_to_attributes(response_data)
        customer_data = response_data.dig("data", "customer")
        return nil unless customer_data

        {
          id: customer_data["id"],
          name: customer_data["displayName"],
          email: customer_data.dig("defaultEmailAddress", "emailAddress"),
          created_at: customer_data["createdAt"]
        }
      end

      def execute_graphql_query(query, **variables)
        @client.execute(query, **variables)
      end
    end.new
  end

  let(:customer_class) do
    Class.new do
      include ActiveShopifyGraphQL::Base

      attr_accessor :id, :name, :email, :created_at

      def self.name
        "Customer"
      end

      def self.model_name
        ActiveModel::Name.new(self, nil, "Customer")
      end

      class << self
        attr_reader :default_loader
      end

      class << self
        attr_writer :default_loader
      end
    end
  end

  before do
    ActiveShopifyGraphQL.configure do |config|
      config.admin_api_client = mock_client
    end

    customer_class.default_loader = mock_loader
  end

  describe ".where" do
    it "builds correct Shopify query syntax for simple conditions" do
      expected_query = <<~GRAPHQL
        fragment CustomerFragment on Customer {
          id
          displayName
          defaultEmailAddress {
            emailAddress
          }
          createdAt
        }

        query getCustomers($query: String, $first: Int!) {
          customers(query: $query, first: $first) {
            nodes {
              ...CustomerFragment
            }
          }
        }
      GRAPHQL

      expected_variables = {
        query: "email:john@example.com AND first_name:John",
        first: 250
      }

      expect(mock_client).to receive(:execute)
        .with(expected_query, **expected_variables)
        .and_return({
                      "data" => {
                        "customers" => {
                          "nodes" => [
                            {
                              "id" => "gid://shopify/Customer/123",
                              "displayName" => "John Doe",
                              "defaultEmailAddress" => { "emailAddress" => "john@example.com" },
                              "createdAt" => "2024-01-01T00:00:00Z"
                            }
                          ]
                        }
                      }
                    })

      results = customer_class.where(email: "john@example.com", first_name: "John")

      expect(results).to have_attributes(size: 1)
      expect(results.first).to have_attributes(
        id: "gid://shopify/Customer/123",
        name: "John Doe",
        email: "john@example.com"
      )
    end

    it "raises ArgumentError when Shopify returns field validation warnings" do
      # Mock a response with search warnings
      mock_response = {
        "data" => { "customers" => { "nodes" => [] } },
        "extensions" => {
          "search" => [{
            "path" => ["customers"],
            "query" => "invalid_field:test",
            "warnings" => [{
              "field" => "invalid_field",
              "message" => "Invalid search field for this query."
            }]
          }]
        }
      }

      expect(mock_client).to receive(:execute).and_return(mock_response)

      expect do
        customer_class.where(invalid_field: "test")
      end.to raise_error(ArgumentError, /Shopify query validation failed: invalid_field: Invalid search field for this query/)
    end

    it "handles range conditions correctly" do
      expected_variables = {
        query: "id:>=100 id:<200",
        first: 250
      }

      expect(mock_client).to receive(:execute)
        .with(anything, **expected_variables)
        .and_return({ "data" => { "customers" => { "nodes" => [] } } })

      customer_class.where(id: { gte: 100, lt: 200 })
    end

    it "handles quoted values for multi-word strings" do
      expected_variables = {
        query: "first_name:\"John Doe\"",
        first: 250
      }

      expect(mock_client).to receive(:execute)
        .with(anything, **expected_variables)
        .and_return({ "data" => { "customers" => { "nodes" => [] } } })

      customer_class.where(first_name: "John Doe")
    end

    it "returns empty array when no results" do
      expect(mock_client).to receive(:execute)
        .and_return({ "data" => { "customers" => { "nodes" => [] } } })

      results = customer_class.where(email: "nonexistent@example.com")
      expect(results).to be_empty
    end
  end
end
