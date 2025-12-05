# frozen_string_literal: true

require 'spec_helper'
require 'json'

RSpec.describe "Metafield attribute functionality" do
  let(:mock_response) do
    {
      "data" => {
        "product" => {
          "id" => "gid://shopify/Product/123",
          "title" => "Test Product",
          "boxesAvailableMetafield" => { "value" => "10" },
          "boxesSentMetafield" => { "jsonValue" => { "count" => 5, "dates" => ["2024-01-01"] } },
          "descriptionMetafield" => { "value" => "SEO description" },
          "isFeaturedMetafield" => { "value" => "true" }
        }
      }
    }
  end

  let(:mock_client) { instance_double("GraphQLClient") }

  before do
    ActiveShopifyGraphQL.configure do |config|
      config.admin_api_client = mock_client
    end
  end

  test_model_class = Class.new do
    include ActiveShopifyGraphQL::Attributes
    include ActiveShopifyGraphQL::MetafieldAttributes

    # Regular attributes
    attribute :id, type: :string
    attribute :title, type: :string

    # Metafield attributes with different types
    metafield_attribute :boxes_available, namespace: 'custom', key: 'available_boxes', type: :integer
    metafield_attribute :boxes_sent, namespace: 'custom', key: 'sent_boxes', type: :json
    metafield_attribute :description, namespace: 'seo', key: 'meta_description', type: :string
    metafield_attribute :is_featured, namespace: 'custom', key: 'featured', type: :boolean, null: false

    def self.name
      'Product'
    end
  end

  test_loader_class = Class.new(ActiveShopifyGraphQL::Loader) do
    graphql_type "Product"
    self.model_class = test_model_class
  end

  describe ".metafield_attribute" do
    it "adds metafield to attributes collection" do
      expect(test_model_class.attributes_for_loader(test_loader_class)).to include(:boxes_available)
      expect(test_model_class.attributes_for_loader(test_loader_class)).to include(:boxes_sent)
    end

    it "stores metafield metadata" do
      expect(test_model_class.metafields[:boxes_available]).to eq({
                                                                    namespace: 'custom',
                                                                    key: 'available_boxes',
                                                                    type: :integer
                                                                  })
    end

    it "creates correct attribute configuration for integer metafields" do
      config = test_model_class.attributes_for_loader(test_loader_class)[:boxes_available]
      expect(config[:path]).to eq("boxesAvailableMetafield.value")
      expect(config[:type]).to eq(:integer)
      expect(config[:is_metafield]).to be true
      expect(config[:metafield_namespace]).to eq('custom')
      expect(config[:metafield_key]).to eq('available_boxes')
    end

    it "creates correct attribute configuration for json metafields" do
      config = test_model_class.attributes_for_loader(test_loader_class)[:boxes_sent]
      expect(config[:path]).to eq("boxesSentMetafield.jsonValue")
      expect(config[:type]).to eq(:json)
      expect(config[:is_metafield]).to be true
    end
  end

  describe "#fragment generation" do
    it "includes metafield GraphQL syntax in generated fragment" do
      loader = test_loader_class.new
      fragment = loader.fragment.to_s

      expect(fragment).to include("fragment ProductFragment on Product {")
      expect(fragment).to include("id")
      expect(fragment).to include("title")
      expect(fragment).to include('boxesAvailableMetafield: metafield(namespace: "custom", key: "available_boxes") {')
      expect(fragment).to include("value")
      expect(fragment).to include('boxesSentMetafield: metafield(namespace: "custom", key: "sent_boxes") {')
      expect(fragment).to include("jsonValue")
    end

    it "uses value field for non-json types" do
      loader = test_loader_class.new
      fragment = loader.fragment.to_s

      expect(fragment).to include('boxesAvailableMetafield: metafield(namespace: "custom", key: "available_boxes") {')
      expect(fragment).to include('descriptionMetafield: metafield(namespace: "seo", key: "meta_description") {')
      expect(fragment).to match(/boxesAvailableMetafield[^}]*value[^}]*}/m)
      expect(fragment).to match(/descriptionMetafield[^}]*value[^}]*}/m)
    end

    it "uses jsonValue field for json type" do
      loader = test_loader_class.new
      fragment = loader.fragment.to_s

      expect(fragment).to include('boxesSentMetafield: metafield(namespace: "custom", key: "sent_boxes") {')
      expect(fragment).to match(/boxesSentMetafield[^}]*jsonValue[^}]*}/m)
    end
  end

  describe "#map_response_to_attributes" do
    it "correctly maps metafield responses to attributes" do
      loader = test_loader_class.new

      attributes = loader.map_response_to_attributes(mock_response)

      expect(attributes[:id]).to eq("gid://shopify/Product/123")
      expect(attributes[:title]).to eq("Test Product")
      expect(attributes[:boxes_available]).to eq(10) # Coerced to integer
      expect(attributes[:boxes_sent]).to eq({ "count" => 5, "dates" => ["2024-01-01"] }) # JSON string preserved
      expect(attributes[:description]).to eq("SEO description")
      expect(attributes[:is_featured]).to be true # Coerced to boolean
    end

    it "handles null metafield values when null is allowed" do
      null_model = Class.new do
        include ActiveShopifyGraphQL::Attributes
        include ActiveShopifyGraphQL::MetafieldAttributes
        metafield_attribute :optional_field, namespace: 'test', key: 'optional', type: :string
        def self.name = 'Product'
      end

      null_response_loader = Class.new(ActiveShopifyGraphQL::Loader) do
        graphql_type "Product"
        self.model_class = null_model

        def execute_graphql_query(_query, **_variables)
          {
            "data" => {
              "product" => {
                "optionalFieldMetafield" => nil
              }
            }
          }
        end
      end

      loader = null_response_loader.new
      response = loader.send(:execute_graphql_query, "")
      attributes = loader.map_response_to_attributes(response)

      expect(attributes[:optional_field]).to be_nil
    end

    it "raises error for null values when null is not allowed" do
      loader = test_loader_class.new

      # Mock a response where the required metafield is null
      allow(loader).to receive(:execute_graphql_query).and_return({
                                                                    "data" => {
                                                                      "product" => {
                                                                        "isFeaturedMetafield" => nil
                                                                      }
                                                                    }
                                                                  })

      response = loader.send(:execute_graphql_query, "")

      expect do
        loader.map_response_to_attributes(response)
      end.to raise_error(ArgumentError, /Attribute 'is_featured'.*cannot be null/)
    end
  end

  describe "#load_attributes integration" do
    it "successfully loads and maps metafield attributes" do
      allow(mock_client).to receive(:execute).and_return(mock_response)

      loader = test_loader_class.new
      attributes = loader.load_attributes("test-id")

      expect(attributes).to include(
        id: "gid://shopify/Product/123",
        title: "Test Product",
        boxes_available: 10,
        boxes_sent: { "count" => 5, "dates" => ["2024-01-01"] },
        description: "SEO description",
        is_featured: true
      )
    end
  end

  describe "edge cases" do
    it "handles metafields with transform blocks" do
      transform_model = Class.new do
        include ActiveShopifyGraphQL::Attributes
        include ActiveShopifyGraphQL::MetafieldAttributes
        metafield_attribute :tags, namespace: 'custom', key: 'tags', type: :json,
                                   transform: ->(tags_array) { tags_array.map(&:upcase) }
        def self.name = 'Product'
      end

      transform_loader = Class.new(ActiveShopifyGraphQL::Loader) do
        graphql_type "Product"
        self.model_class = transform_model
      end

      allow(mock_client).to receive(:execute).and_return(
        {
          "data" => {
            "product" => {
              "tagsMetafield" => { "jsonValue" => %w[tag1 tag2] }
            }
          }
        }
      )

      loader = transform_loader.new
      attributes = loader.load_attributes("test-id")

      expect(attributes[:tags]).to eq(%w[TAG1 TAG2])
    end

    it "handles nil metafields with default values" do
      default_model = Class.new do
        include ActiveShopifyGraphQL::Attributes
        include ActiveShopifyGraphQL::MetafieldAttributes
        metafield_attribute :missing_string, namespace: 'custom', key: 'missing_str', type: :string,
                                             default: "default_value"
        metafield_attribute :missing_json, namespace: 'custom', key: 'missing_json', type: :json,
                                           default: { "default" => true }
        metafield_attribute :missing_integer, namespace: 'custom', key: 'missing_int', type: :integer,
                                              default: 42
        def self.name = 'Product'
      end

      default_loader = Class.new(ActiveShopifyGraphQL::Loader) do
        graphql_type "Product"
        self.model_class = default_model
      end

      allow(mock_client).to receive(:execute).and_return(
        {
          "data" => {
            "product" => {
              "missingStringMetafield" => nil,
              "missingJsonMetafield" => nil,
              "missingIntegerMetafield" => nil
            }
          }
        }
      )

      loader = default_loader.new
      attributes = loader.load_attributes("test-id")

      expect(attributes[:missing_string]).to eq("default_value")
      expect(attributes[:missing_json]).to eq({ "default" => true })
      expect(attributes[:missing_integer]).to eq(42)
    end

    it "handles nil metafields with transform blocks providing defaults" do
      transform_model = Class.new do
        include ActiveShopifyGraphQL::Attributes
        include ActiveShopifyGraphQL::MetafieldAttributes
        metafield_attribute :missing_string, namespace: 'custom', key: 'missing', type: :string,
                                             transform: ->(value) { value.nil? ? "transform_default" : value }
        metafield_attribute :missing_json, namespace: 'custom', key: 'json', type: :json,
                                           transform: ->(value) { value.nil? ? { "transform" => true } : value }
        def self.name = 'Product'
      end

      transform_loader = Class.new(ActiveShopifyGraphQL::Loader) do
        graphql_type "Product"
        self.model_class = transform_model
      end

      allow(mock_client).to receive(:execute).and_return(
        {
          "data" => {
            "product" => {
              "missingStringMetafield" => nil,
              "missingJsonMetafield" => nil
            }
          }
        }
      )

      loader = transform_loader.new
      attributes = loader.load_attributes("test-id")

      expect(attributes[:missing_string]).to eq("transform_default")
      expect(attributes[:missing_json]).to eq({ "transform" => true })
    end

    it "prefers default over transform for nil values (optimization)" do
      call_count = 0
      transform_proc = lambda { |_value|
        call_count += 1
        "transform_should_not_be_called"
      }
      transform_proc2 = lambda { |_value|
        call_count += 1
        "transform_called"
      }

      mixed_model = Class.new do
        include ActiveShopifyGraphQL::Attributes
        include ActiveShopifyGraphQL::MetafieldAttributes

        # This should use default and NOT call transform
        metafield_attribute :with_default, namespace: 'custom', key: 'def', type: :string,
                                           default: "default_used",
                                           transform: transform_proc

        # This should call transform since no default
        metafield_attribute :with_transform, namespace: 'custom', key: 'trans', type: :string,
                                             transform: transform_proc2
        def self.name = 'Product'
      end

      mixed_loader = Class.new(ActiveShopifyGraphQL::Loader) do
        graphql_type "Product"
        self.model_class = mixed_model
      end

      allow(mock_client).to receive(:execute).and_return(
        {
          "data" => {
            "product" => {
              "withDefaultMetafield" => nil,
              "withTransformMetafield" => nil
            }
          }
        }
      )

      loader = mixed_loader.new
      attributes = loader.load_attributes("test-id")

      expect(attributes[:with_default]).to eq("default_used")
      expect(attributes[:with_transform]).to eq("transform_called")
      expect(call_count).to eq(1) # Only transform should be called once
    end

    it "generates unique aliases for metafields with same namespace/key but different names" do
      multi_model = Class.new do
        include ActiveShopifyGraphQL::Attributes
        include ActiveShopifyGraphQL::MetafieldAttributes
        metafield_attribute :weight_kg, namespace: 'shipping', key: 'weight', type: :float
        metafield_attribute :weight_display, namespace: 'shipping', key: 'weight', type: :string
        def self.name = 'Product'
      end

      multi_loader = Class.new(ActiveShopifyGraphQL::Loader) do
        graphql_type "Product"
        self.model_class = multi_model

        def fragment
          ActiveShopifyGraphQL::Fragment.new(
            graphql_type: graphql_type,
            loader_class: self.class,
            defined_attributes: defined_attributes,
            model_class: instance_variable_get(:@model_class),
            included_connections: instance_variable_get(:@included_connections)
          ).to_s
        end
      end

      loader = multi_loader.new
      fragment = loader.fragment

      expect(fragment).to include('weightKgMetafield: metafield(namespace: "shipping", key: "weight")')
      expect(fragment).to include('weightDisplayMetafield: metafield(namespace: "shipping", key: "weight")')
    end
  end
end
