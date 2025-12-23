# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Loader do
  describe "#initialize" do
    it "requires model_class parameter" do
      loader_class = Class.new(described_class)

      expect { loader_class.new }.to raise_error(ArgumentError, /wrong number of arguments/)
    end

    it "accepts model_class parameter" do
      model_class = build_loader_protocol_class(graphql_type: "TestModel")
      loader_class = Class.new(described_class)

      loader = loader_class.new(model_class)

      expect(loader.context.graphql_type).to eq("TestModel")
    end

    it "accepts selected_attributes parameter" do
      model_class = build_loader_protocol_class(
        graphql_type: "TestModel",
        attributes: {
          id: { path: "id", type: :string },
          name: { path: "name", type: :string },
          email: { path: "email", type: :string }
        }
      )
      loader_class = Class.new(described_class)

      loader = loader_class.new(model_class, selected_attributes: %i[id name])

      expect(loader.defined_attributes.keys).to contain_exactly(:id, :name)
    end

    it "always includes id in selected_attributes" do
      model_class = build_loader_protocol_class(
        graphql_type: "TestModel",
        attributes: {
          id: { path: "id", type: :string },
          name: { path: "name", type: :string }
        }
      )
      loader_class = Class.new(described_class)

      loader = loader_class.new(model_class, selected_attributes: [:name])

      expect(loader.defined_attributes.keys).to contain_exactly(:id, :name)
    end
  end

  describe "#context" do
    it "returns a LoaderContext with correct values" do
      model_class = build_loader_protocol_class(graphql_type: "TestModel")
      loader_class = Class.new(described_class)
      loader = loader_class.new(model_class)

      context = loader.context

      expect(context).to be_a(ActiveShopifyGraphQL::LoaderContext)
      expect(context.graphql_type).to eq("TestModel")
      expect(context.model_class).to eq(model_class)
    end

    it "provides query_name as lowerCamelCase graphql_type" do
      model_class = build_loader_protocol_class(graphql_type: "TestModel")
      loader_class = Class.new(described_class)
      loader = loader_class.new(model_class)

      expect(loader.context.query_name).to eq("testModel")
    end

    it "provides fragment_name with Fragment suffix" do
      model_class = build_loader_protocol_class(graphql_type: "TestModel")
      loader_class = Class.new(described_class)
      loader = loader_class.new(model_class)

      expect(loader.context.fragment_name).to eq("TestModelFragment")
    end
  end

  describe "#map_response_to_attributes" do
    it "maps GraphQL response to attribute hash" do
      model_class = build_loader_protocol_class(
        graphql_type: "TestModel",
        attributes: {
          id: { path: "id", type: :string },
          name: { path: "name", type: :string }
        }
      )
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
      model_class = build_loader_protocol_class(
        graphql_type: "TestModel",
        attributes: {
          id: { path: "id", type: :string },
          name: { path: "name", type: :string }
        }
      )
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
      model_class = build_loader_protocol_class(graphql_type: "TestModel")
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
      model_class = build_loader_protocol_class(graphql_type: "TestModel")
      loader_class = Class.new(described_class)
      loader = loader_class.new(model_class)

      expect { loader.perform_graphql_query("query { test }") }.to raise_error(NotImplementedError)
    end
  end
end
