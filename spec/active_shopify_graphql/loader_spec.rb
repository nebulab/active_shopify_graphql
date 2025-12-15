# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Loader do
  describe ".graphql_type" do
    it "allows setting graphql_type at class level" do
      loader_class = Class.new(described_class) do
        graphql_type "TestModel"
      end

      expect(loader_class.graphql_type).to eq("TestModel")
    end

    it "raises error when graphql_type is not set" do
      loader_class = Class.new(described_class)

      expect { loader_class.graphql_type }.to raise_error(NotImplementedError)
    end

    it "gets graphql_type from associated model class when available" do
      model_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "ModelType" }
      end
      loader_class = Class.new(described_class)
      loader_class.model_class = model_class

      expect(loader_class.graphql_type).to eq("ModelType")
    end
  end

  describe "#initialize" do
    it "accepts model_class parameter" do
      model_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "TestModel" }
        define_singleton_method(:attributes_for_loader) { |_| { id: { path: "id", type: :string } } }
      end
      loader_class = Class.new(described_class)

      loader = loader_class.new(model_class)

      expect(loader.graphql_type).to eq("TestModel")
    end

    it "accepts selected_attributes parameter" do
      model_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "TestModel" }
        define_singleton_method(:attributes_for_loader) do |_|
          {
            id: { path: "id", type: :string },
            name: { path: "name", type: :string },
            email: { path: "email", type: :string }
          }
        end
      end
      loader_class = Class.new(described_class)

      loader = loader_class.new(model_class, selected_attributes: %i[id name])

      expect(loader.defined_attributes.keys).to contain_exactly(:id, :name)
    end

    it "always includes id in selected_attributes" do
      model_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "TestModel" }
        define_singleton_method(:attributes_for_loader) do |_|
          {
            id: { path: "id", type: :string },
            name: { path: "name", type: :string }
          }
        end
      end
      loader_class = Class.new(described_class)

      loader = loader_class.new(model_class, selected_attributes: [:name])

      expect(loader.defined_attributes.keys).to contain_exactly(:id, :name)
    end
  end

  describe "#context" do
    it "returns a LoaderContext with correct values" do
      model_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "TestModel" }
        define_singleton_method(:attributes_for_loader) { |_| { id: { path: "id", type: :string } } }
        define_singleton_method(:connections) { {} }
      end
      loader_class = Class.new(described_class)
      loader = loader_class.new(model_class)

      context = loader.context

      expect(context).to be_a(ActiveShopifyGraphQL::LoaderContext)
      expect(context.graphql_type).to eq("TestModel")
      expect(context.model_class).to eq(model_class)
    end
  end

  describe "#query_name" do
    it "returns lowerCamelCase graphql_type" do
      model_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "TestModel" }
        define_singleton_method(:attributes_for_loader) { |_| { id: { path: "id", type: :string } } }
      end
      loader_class = Class.new(described_class)
      loader = loader_class.new(model_class)

      expect(loader.query_name).to eq("testModel")
    end
  end

  describe "#fragment_name" do
    it "returns graphql_type with Fragment suffix" do
      model_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "TestModel" }
        define_singleton_method(:attributes_for_loader) { |_| { id: { path: "id", type: :string } } }
      end
      loader_class = Class.new(described_class)
      loader = loader_class.new(model_class)

      expect(loader.fragment_name).to eq("TestModelFragment")
    end
  end

  describe "#fragment" do
    it "builds fragment from model attributes" do
      model_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "TestModel" }
        define_singleton_method(:attributes_for_loader) do |_|
          {
            id: { path: "id", type: :string },
            name: { path: "displayName", type: :string }
          }
        end
        define_singleton_method(:connections) { {} }
      end
      loader_class = Class.new(described_class)
      loader = loader_class.new(model_class)

      fragment = loader.fragment.to_s

      expect(fragment).to include("fragment TestModelFragment on TestModel")
      expect(fragment).to include("id")
      expect(fragment).to include("displayName")
    end

    it "raises error when attributes are empty" do
      model_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "NoAttrs" }
        define_singleton_method(:attributes_for_loader) { |_| {} }
        define_singleton_method(:connections) { {} }
      end
      loader_class = Class.new(described_class)
      loader = loader_class.new(model_class)

      expect { loader.fragment.to_s }.to raise_error(NotImplementedError, /must define attributes/)
    end
  end

  describe "#graphql_query" do
    it "generates correct GraphQL query structure" do
      model_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "TestModel" }
        define_singleton_method(:attributes_for_loader) do |_|
          { id: { path: "id", type: :string }, name: { path: "name", type: :string } }
        end
        define_singleton_method(:connections) { {} }
      end
      loader_class = Class.new(described_class)
      loader = loader_class.new(model_class)

      query = loader.graphql_query

      expect(query).to include("query getTestModel($id: ID!)")
      expect(query).to include("testModel(id: $id)")
      expect(query).to include("...TestModelFragment")
    end
  end

  describe "#map_response_to_attributes" do
    it "maps GraphQL response to attribute hash" do
      model_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "TestModel" }
        define_singleton_method(:attributes_for_loader) do |_|
          {
            id: { path: "id", type: :string },
            name: { path: "name", type: :string }
          }
        end
        define_singleton_method(:connections) { {} }
      end
      loader_class = Class.new(described_class)
      loader = loader_class.new(model_class)
      response_data = {
        "data" => {
          "testModel" => {
            "id" => "gid://shopify/TestModel/123",
            "name" => "Test"
          }
        }
      }

      result = loader.map_response_to_attributes(response_data)

      expect(result).to eq({
                             id: "gid://shopify/TestModel/123",
                             name: "Test"
                           })
    end
  end

  describe "#load_attributes" do
    it "executes query and returns mapped attributes" do
      model_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "TestModel" }
        define_singleton_method(:attributes_for_loader) do |_|
          { id: { path: "id", type: :string }, name: { path: "name", type: :string } }
        end
        define_singleton_method(:connections) { {} }
      end
      loader_class = Class.new(described_class) do
        define_method(:perform_graphql_query) do |_query, **_variables|
          { "data" => { "testModel" => { "id" => "test-id", "name" => "Test Name" } } }
        end
      end
      loader = loader_class.new(model_class)

      result = loader.load_attributes("test-id")

      expect(result[:id]).to eq("test-id")
      expect(result[:name]).to eq("Test Name")
    end

    it "returns nil when response is nil" do
      model_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "TestModel" }
        define_singleton_method(:attributes_for_loader) { |_| { id: { path: "id", type: :string } } }
        define_singleton_method(:connections) { {} }
      end
      loader_class = Class.new(described_class) do
        define_method(:perform_graphql_query) { |_query, **_variables| nil }
      end
      loader = loader_class.new(model_class)

      result = loader.load_attributes("test-id")

      expect(result).to be_nil
    end
  end

  describe "#perform_graphql_query" do
    it "raises NotImplementedError in base class" do
      model_class = Class.new do
        define_singleton_method(:graphql_type_for_loader) { |_| "TestModel" }
        define_singleton_method(:attributes_for_loader) { |_| { id: { path: "id", type: :string } } }
        define_singleton_method(:connections) { {} }
      end
      loader_class = Class.new(described_class)
      loader = loader_class.new(model_class)

      expect { loader.perform_graphql_query("query { test }") }.to raise_error(NotImplementedError)
    end
  end
end
