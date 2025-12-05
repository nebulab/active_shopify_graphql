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
    let(:test_model_class) do
      Class.new do
        include ActiveShopifyGraphQL::Attributes

        attribute :id
        attribute :name

        def self.graphql_type_for_loader(_loader_class)
          "TestModel"
        end

        def self.name
          "TestModel"
        end
      end
    end

    let(:test_loader_class) do
      model_class = test_model_class
      Class.new(described_class) do
        graphql_type "TestModel"

        define_method(:initialize) do |model_class_arg = model_class, **options|
          super(model_class_arg, **options)
        end

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
      fragment = loader.fragment.to_s

      expect(fragment).to include("fragment TestModelFragment on TestModel {")
      expect(fragment).to include("id")
      expect(fragment).to include("name")
      expect(fragment).to include("}")
    end

    it 'generates fragment from attributes' do
      loader = test_loader_class.new
      fragment = loader.fragment.to_s
      expect(fragment).to include("id")
      expect(fragment).to include("name")
    end

    it 'raises error when fragment is not defined' do
      empty_model_class = Class.new do
        include ActiveShopifyGraphQL::Attributes

        def self.graphql_type_for_loader(_loader_class)
          "NoFragment"
        end

        def self.name
          "NoFragment"
        end
      end

      loader_without_fragment = Class.new(described_class) do
        graphql_type "NoFragment"

        define_method(:initialize) do |model_class_arg = empty_model_class, **options|
          super(model_class_arg, **options)
        end
      end

      expect { loader_without_fragment.new.fragment.to_s }.to raise_error(NotImplementedError, /must define attributes/)
    end

    it 'loads attributes using graphql_type' do
      allow(mock_client).to receive(:execute).and_return(
        { "data" => { "testmodel" => { "id" => "test-id" } } }
      )

      loader = test_loader_class.new
      result = loader.load_attributes("test-id")

      expect(result).to eq({ id: "test-id" })
    end
  end
end
