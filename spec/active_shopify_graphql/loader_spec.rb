# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ActiveShopifyGraphQL::Loader do
  let(:mock_client) { double("GraphQLClient") }

  before do
    ActiveShopifyGraphQL.configure do |config|
      config.admin_api_client = mock_client
    end
  end

  describe '.graphql_type and .fragment' do
    let(:test_loader_class) do
      Class.new(described_class) do
        graphql_type "TestModel"
        fragment <<~GRAPHQL
          id
          name
        GRAPHQL

        def map_response_to_attributes(response_data)
          { id: response_data.dig("data", "testmodel", "id") }
        end
      end
    end

    it 'allows setting graphql_type at class level' do
      expect(test_loader_class.graphql_type).to eq("TestModel")
    end

    it 'raises error when graphql_type is not set' do
      loader_without_type = Class.new(described_class)
      expect { loader_without_type.graphql_type }.to raise_error(NotImplementedError)
    end

    it 'generates correct query_name from graphql_type' do
      loader = test_loader_class.new
      expect(loader.query_name).to eq("testmodel")
    end

    it 'generates correct fragment_name from graphql_type' do
      loader = test_loader_class.new
      expect(loader.fragment_name).to eq("TestModelFragment")
    end

    it 'generates correct GraphQL query using graphql_type' do
      loader = test_loader_class.new
      query = loader.graphql_query

      expect(query).to include("query getTestModel($id: ID!)")
      expect(query).to include("testmodel(id: $id)")
      expect(query).to include("...TestModelFragment")
    end

    it 'builds fragment automatically from class-level fragment definition' do
      loader = test_loader_class.new
      fragment = loader.fragment

      expect(fragment).to include("fragment TestModelFragment on TestModel {")
      expect(fragment).to include("id")
      expect(fragment).to include("name")
      expect(fragment).to include("}")
    end

    it 'allows getting fragment fields at class level' do
      expect(test_loader_class.fragment).to include("id")
      expect(test_loader_class.fragment).to include("name")
    end

    it 'raises error when fragment is not defined' do
      loader_without_fragment = Class.new(described_class) do
        graphql_type "NoFragment"
      end

      expect { loader_without_fragment.fragment }.to raise_error(NotImplementedError)
    end

    it 'loads attributes using graphql_type' do
      allow(mock_client).to receive(:execute).and_return(
        { "data" => { "testmodel" => { "id" => "test-id" } } }
      )

      loader = test_loader_class.new
      result = loader.load_attributes("test-id")

      expect(result).to eq({ id: "test-id" })
    end

    context 'backwards compatibility' do
      it 'still accepts model_type parameter in load_attributes' do
        allow(mock_client).to receive(:execute).and_return(
          { "data" => { "testmodel" => { "id" => "test-id" } } }
        )

        loader = test_loader_class.new
        result = loader.load_attributes("CustomType", "test-id")

        expect(result).to eq({ id: "test-id" })
      end

      it 'still accepts model_type parameter in other methods' do
        loader = test_loader_class.new

        expect(loader.query_name("CustomType")).to eq("customtype")
        expect(loader.fragment_name("CustomType")).to eq("CustomTypeFragment")
      end
    end
  end
end
