# frozen_string_literal: true

require 'spec_helper'
require 'json'

RSpec.describe "Metafield attribute functionality" do
  let(:test_loader_class) do
    Class.new(ActiveShopifyGraphQL::Loader) do
      graphql_type "Product"

      # Regular attributes
      attribute :id, type: :string
      attribute :title, type: :string

      # Metafield attributes with different types
      metafield_attribute :boxes_available, namespace: 'custom', key: 'available_boxes', type: :integer
      metafield_attribute :boxes_sent, namespace: 'custom', key: 'sent_boxes', type: :json
      metafield_attribute :description, namespace: 'seo', key: 'meta_description', type: :string
      metafield_attribute :is_featured, namespace: 'custom', key: 'featured', type: :boolean, null: false

      def execute_graphql_query(_query, **_variables)
        {
          "data" => {
            "product" => {
              "id" => "gid://shopify/Product/123",
              "title" => "Test Product",
              "boxes_availableMetafield" => { "value" => "10" },
              "boxes_sentMetafield" => { "jsonValue" => { "count" => 5, "dates" => ["2024-01-01"] } },
              "descriptionMetafield" => { "value" => "SEO description" },
              "is_featuredMetafield" => { "value" => "true" }
            }
          }
        }
      end
    end
  end

  describe ".metafield_attribute" do
    it "adds metafield to attributes collection" do
      expect(test_loader_class.attributes).to include(:boxes_available)
      expect(test_loader_class.attributes).to include(:boxes_sent)
    end

    it "stores metafield metadata" do
      expect(test_loader_class.metafields[:boxes_available]).to eq({
                                                                     namespace: 'custom',
                                                                     key: 'available_boxes',
                                                                     type: :integer
                                                                   })
    end

    it "creates correct attribute configuration for integer metafields" do
      config = test_loader_class.attributes[:boxes_available]
      expect(config[:path]).to eq("boxes_availableMetafield.value")
      expect(config[:type]).to eq(:integer)
      expect(config[:is_metafield]).to be true
      expect(config[:metafield_namespace]).to eq('custom')
      expect(config[:metafield_key]).to eq('available_boxes')
    end

    it "creates correct attribute configuration for json metafields" do
      config = test_loader_class.attributes[:boxes_sent]
      expect(config[:path]).to eq("boxes_sentMetafield.jsonValue")
      expect(config[:type]).to eq(:json)
      expect(config[:is_metafield]).to be true
    end
  end

  describe "#fragment generation" do
    it "includes metafield GraphQL syntax in generated fragment" do
      loader = test_loader_class.new
      fragment = loader.fragment

      expect(fragment).to include("fragment ProductFragment on Product {")
      expect(fragment).to include("id")
      expect(fragment).to include("title")
      expect(fragment).to include('boxes_availableMetafield: metafield(namespace: "custom", key: "available_boxes") {')
      expect(fragment).to include("value")
      expect(fragment).to include('boxes_sentMetafield: metafield(namespace: "custom", key: "sent_boxes") {')
      expect(fragment).to include("jsonValue")
    end

    it "uses value field for non-json types" do
      loader = test_loader_class.new
      fragment = loader.fragment

      expect(fragment).to include('boxes_availableMetafield: metafield(namespace: "custom", key: "available_boxes") {')
      expect(fragment).to include('descriptionMetafield: metafield(namespace: "seo", key: "meta_description") {')
      expect(fragment).to match(/boxes_availableMetafield[^}]*value[^}]*}/m)
      expect(fragment).to match(/descriptionMetafield[^}]*value[^}]*}/m)
    end

    it "uses jsonValue field for json type" do
      loader = test_loader_class.new
      fragment = loader.fragment

      expect(fragment).to include('boxes_sentMetafield: metafield(namespace: "custom", key: "sent_boxes") {')
      expect(fragment).to match(/boxes_sentMetafield[^}]*jsonValue[^}]*}/m)
    end
  end

  describe "#map_response_to_attributes" do
    it "correctly maps metafield responses to attributes" do
      loader = test_loader_class.new
      response = loader.send(:execute_graphql_query, "", id: "test")

      attributes = loader.map_response_to_attributes(response)

      expect(attributes[:id]).to eq("gid://shopify/Product/123")
      expect(attributes[:title]).to eq("Test Product")
      expect(attributes[:boxes_available]).to eq(10) # Coerced to integer
      expect(attributes[:boxes_sent]).to eq({ "count" => 5, "dates" => ["2024-01-01"] }) # JSON string preserved
      expect(attributes[:description]).to eq("SEO description")
      expect(attributes[:is_featured]).to be true # Coerced to boolean
    end

    it "handles null metafield values when null is allowed" do
      null_response_loader = Class.new(ActiveShopifyGraphQL::Loader) do
        graphql_type "Product"

        metafield_attribute :optional_field, namespace: 'test', key: 'optional', type: :string

        def execute_graphql_query(_query, **_variables)
          {
            "data" => {
              "product" => {
                "optional_fieldMetafield" => nil
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
                                                                        "is_featuredMetafield" => nil
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
      transform_loader = Class.new(ActiveShopifyGraphQL::Loader) do
        graphql_type "Product"

        metafield_attribute :tags, namespace: 'custom', key: 'tags', type: :json,
                                   transform: ->(tags_array) { tags_array.map(&:upcase) }

        def execute_graphql_query(_query, **_variables)
          {
            "data" => {
              "product" => {
                "tagsMetafield" => { "jsonValue" => %w[tag1 tag2] }
              }
            }
          }
        end
      end

      loader = transform_loader.new
      attributes = loader.load_attributes("test-id")

      expect(attributes[:tags]).to eq(%w[TAG1 TAG2])
    end

    it "handles nil metafields with default values" do
      default_loader = Class.new(ActiveShopifyGraphQL::Loader) do
        graphql_type "Product"

        metafield_attribute :missing_string, namespace: 'custom', key: 'missing_str', type: :string,
                                             default: "default_value"

        metafield_attribute :missing_json, namespace: 'custom', key: 'missing_json', type: :json,
                                           default: { "default" => true }

        metafield_attribute :missing_integer, namespace: 'custom', key: 'missing_int', type: :integer,
                                              default: 42

        def execute_graphql_query(_query, **_variables)
          {
            "data" => {
              "product" => {
                "missing_stringMetafield" => nil,
                "missing_jsonMetafield" => nil,
                "missing_integerMetafield" => nil
              }
            }
          }
        end
      end

      loader = default_loader.new
      attributes = loader.load_attributes("test-id")

      expect(attributes[:missing_string]).to eq("default_value")
      expect(attributes[:missing_json]).to eq({ "default" => true })
      expect(attributes[:missing_integer]).to eq(42)
    end

    it "handles nil metafields with transform blocks providing defaults" do
      transform_loader = Class.new(ActiveShopifyGraphQL::Loader) do
        graphql_type "Product"

        metafield_attribute :missing_string, namespace: 'custom', key: 'missing', type: :string,
                                             transform: ->(value) { value.nil? ? "transform_default" : value }

        metafield_attribute :missing_json, namespace: 'custom', key: 'json', type: :json,
                                           transform: ->(value) { value.nil? ? { "transform" => true } : value }

        def execute_graphql_query(_query, **_variables)
          {
            "data" => {
              "product" => {
                "missing_stringMetafield" => nil,
                "missing_jsonMetafield" => nil
              }
            }
          }
        end
      end

      loader = transform_loader.new
      attributes = loader.load_attributes("test-id")

      expect(attributes[:missing_string]).to eq("transform_default")
      expect(attributes[:missing_json]).to eq({ "transform" => true })
    end

    it "prefers default over transform for nil values (optimization)" do
      call_count = 0

      mixed_loader = Class.new(ActiveShopifyGraphQL::Loader) do
        graphql_type "Product"

        # This should use default and NOT call transform
        metafield_attribute :with_default, namespace: 'custom', key: 'def', type: :string,
                                           default: "default_used",
                                           transform: lambda { |_value|
                                             call_count += 1
                                             "transform_should_not_be_called"
                                           }

        # This should call transform since no default
        metafield_attribute :with_transform, namespace: 'custom', key: 'trans', type: :string,
                                             transform: lambda { |_value|
                                               call_count += 1
                                               "transform_called"
                                             }

        def execute_graphql_query(_query, **_variables)
          {
            "data" => {
              "product" => {
                "with_defaultMetafield" => nil,
                "with_transformMetafield" => nil
              }
            }
          }
        end
      end

      loader = mixed_loader.new
      attributes = loader.load_attributes("test-id")

      expect(attributes[:with_default]).to eq("default_used")
      expect(attributes[:with_transform]).to eq("transform_called")
      expect(call_count).to eq(1) # Only transform should be called once
    end

    it "generates unique aliases for metafields with same namespace/key but different names" do
      multi_loader = Class.new(ActiveShopifyGraphQL::Loader) do
        graphql_type "Product"

        metafield_attribute :weight_kg, namespace: 'shipping', key: 'weight', type: :float
        metafield_attribute :weight_display, namespace: 'shipping', key: 'weight', type: :string

        def fragment
          ActiveShopifyGraphQL::FragmentBuilder.new(self).build_fragment_from_fields
        end
      end

      loader = multi_loader.new
      fragment = loader.fragment

      expect(fragment).to include('weight_kgMetafield: metafield(namespace: "shipping", key: "weight")')
      expect(fragment).to include('weight_displayMetafield: metafield(namespace: "shipping", key: "weight")')
    end
  end
end
