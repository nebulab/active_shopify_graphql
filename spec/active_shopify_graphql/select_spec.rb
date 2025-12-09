# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Select functionality" do
  let(:mock_client) do
    instance_double("GraphQLClient")
  end

  let(:customer_class) do
    Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type "Customer"

      attribute :id, path: "id", type: :string
      attribute :name, path: "displayName", type: :string
      attribute :email, path: "defaultEmailAddress.emailAddress", type: :string
      attribute :first_name, path: "firstName", type: :string
      attribute :created_at, path: "createdAt", type: :datetime

      def self.name
        "Customer"
      end

      def self.model_name
        ActiveModel::Name.new(self, nil, "Customer")
      end

      class << self
        attr_accessor :default_loader_instance
      end
    end
  end

  before do
    ActiveShopifyGraphQL.configure do |config|
      config.admin_api_client = mock_client
    end

    customer_class.default_loader_instance = ActiveShopifyGraphQL::Loaders::AdminApiLoader.new(customer_class)
  end

  describe ".select" do
    it "returns a modified class that can be used for method chaining" do
      selected_class = customer_class.select(:id, :name)
      expect(selected_class).to be_a(Class)
      expect(selected_class).to respond_to(:find)
      expect(selected_class).to respond_to(:where)
    end

    it "creates a loader with selected attributes" do
      selected_class = customer_class.select(:id, :name)
      loader = selected_class.default_loader

      # Should only include selected attributes plus id (always included)
      attrs = loader.defined_attributes
      expect(attrs.keys).to contain_exactly(:id, :name)
      expect(attrs[:id][:path]).to eq("id")
      expect(attrs[:name][:path]).to eq("displayName")
    end

    it "always includes id even if not explicitly selected" do
      selected_class = customer_class.select(:name)
      loader = selected_class.default_loader
      attrs = loader.defined_attributes

      expect(attrs.keys).to include(:id)
      expect(attrs.keys).to include(:name)
    end

    it "generates GraphQL fragments with only selected attributes" do
      selected_class = customer_class.select(:name, :email)
      loader = selected_class.default_loader
      fragment = loader.fragment.to_s

      expect(fragment).to include("id") # Always included
      expect(fragment).to include("displayName")
      expect(fragment).to include("defaultEmailAddress")
      expect(fragment).to include("emailAddress")
      expect(fragment).not_to include("firstName")
      expect(fragment).not_to include("createdAt")
    end

    it "validates that selected attributes exist" do
      expect do
        customer_class.select(:nonexistent_attribute)
      end.to raise_error(ArgumentError, /Invalid attributes.*nonexistent_attribute/)
    end

    it "provides helpful error message with available attributes" do
      expect do
        customer_class.select(:bad_attr)
      end.to raise_error(ArgumentError) do |error|
        expect(error.message).to include("Available attributes are:")
        # The exact order may vary, but these should be included
        expect(error.message).to match(/\bcreated_at\b/)
        expect(error.message).to match(/\bemail\b/)
        expect(error.message).to match(/\bfirst_name\b/)
        expect(error.message).to match(/\bid\b/)
        expect(error.message).to match(/\bname\b/)
      end
    end

    it "preserves the original class name and model name" do
      selected_class = customer_class.select(:id, :name)
      expect(selected_class.name).to eq("Customer")
      expect(selected_class.model_name).to eq(customer_class.model_name)
    end
  end

  describe "integration with find and where" do
    it "works with find method" do
      expected_response = {
        "data" => {
          "customer" => {
            "id" => "gid://shopify/Customer/123",
            "displayName" => "John Doe"
          }
        }
      }

      expect(mock_client).to receive(:execute) do |query, **variables|
        # Verify the fragment only includes selected attributes and id
        expect(query).to include("id")
        expect(query).to include("displayName")
        expect(query).not_to include("defaultEmailAddress")
        expect(query).not_to include("firstName")
        expect(variables[:id].to_s).to eq("gid://shopify/Customer/123")
        expected_response
      end

      customer = customer_class.select(:name).find(123)
      expect(customer).to be_a(customer_class)
      expect(customer.name).to eq("John Doe")
    end

    it "works with where method" do
      expected_response = {
        "data" => {
          "customers" => {
            "nodes" => [
              {
                "id" => "gid://shopify/Customer/123",
                "displayName" => "John Doe"
              }
            ]
          }
        }
      }

      expect(mock_client).to receive(:execute) do |query, **variables|
        # Verify the fragment only includes selected attributes and id
        expect(query).to include("id")
        expect(query).to include("displayName")
        expect(query).not_to include("defaultEmailAddress")
        expect(query).not_to include("firstName")
        expect(variables[:query]).to eq("first_name:John")
        expected_response
      end

      customers = customer_class.select(:name).where(first_name: "John")
      expect(customers).to be_an(Array)
      expect(customers.size).to eq(1)
      expect(customers.first.name).to eq("John Doe")
    end
  end
end
