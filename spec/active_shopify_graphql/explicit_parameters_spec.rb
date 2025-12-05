# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Explicit Connection Parameters" do
  # Create test model classes
  let(:order_class) do
    Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type 'Order'

      attribute :id
      # Explicit parameters required - no defaults
      connection :line_items, default_arguments: { first: 5 }

      def self.name
        'Order'
      end
    end
  end

  let(:line_item_class) do
    Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type 'LineItem'

      attribute :id

      def self.name
        'LineItem'
      end
    end
  end

  let(:product_class) do
    Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type 'Product'

      attribute :id
      # Root-level connection with explicit parameters
      connection :variants, default_arguments: { first: 10, sort_key: 'CREATED_AT', reverse: false }

      def self.name
        'Product'
      end
    end
  end

  let(:product_variant_class) do
    Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type 'ProductVariant'

      attribute :id

      def self.name
        'ProductVariant'
      end
    end
  end

  before do
    stub_const('Order', order_class)
    stub_const('LineItem', line_item_class)
    stub_const('Product', product_class)
    stub_const('ProductVariant', product_variant_class)
  end

  describe "explicit parameter requirements" do
    it "stores only explicitly provided parameters" do
      # Order connection with minimal explicit params
      order_connections = order_class.connections
      line_items_config = order_connections[:line_items]

      expect(line_items_config[:default_arguments][:first]).to eq(5)
      expect(line_items_config[:default_arguments][:sort_key]).to be_nil  # Not provided
      expect(line_items_config[:default_arguments][:reverse]).to be_nil   # Not provided
    end

    it "stores all explicitly provided parameters for root-level connections" do
      # Product connection with all explicit params
      product_connections = product_class.connections
      variants_config = product_connections[:variants]

      expect(variants_config[:default_arguments][:first]).to eq(10)
      expect(variants_config[:default_arguments][:sort_key]).to eq('CREATED_AT')
      expect(variants_config[:default_arguments][:reverse]).to be false
    end
  end

  describe "GraphQL variable generation" do
    it "includes only user-specified parameters for nested connections" do
      order = order_class.new(id: 1)
      connection_proxy = order.line_items

      # Access the private method to test variable building
      variables = connection_proxy.send(:build_connection_variables)

      # Should only include first (user-specified)
      expect(variables[:first]).to eq(5)
      # Should not include query or sort_key for nested connections
      expect(variables).not_to have_key(:query)
      expect(variables).not_to have_key(:sort_key)
      # Should not include reverse since it wasn't specified
      expect(variables).not_to have_key(:reverse)
    end

    it "includes user-specified parameters for root-level connections" do
      product = product_class.new(id: 1)
      connection_proxy = product.variants

      # Access the private method to test variable building
      variables = connection_proxy.send(:build_connection_variables)

      # Should include all user-specified parameters
      expect(variables[:first]).to eq(10)
      expect(variables[:sort_key]).to eq('CREATED_AT')
      expect(variables[:reverse]).to be false
    end
  end

  describe "runtime parameter overrides" do
    it "allows runtime overrides while respecting nested/root-level rules" do
      order = order_class.new(id: 1)

      # Override first parameter at runtime
      connection_proxy = order.line_items(first: 20)
      variables = connection_proxy.send(:build_connection_variables)

      expect(variables[:first]).to eq(20) # Runtime override
      # Still no query or sort_key for nested connections
      expect(variables).not_to have_key(:query)
      expect(variables).not_to have_key(:sort_key)
    end
  end
end
