# frozen_string_literal: true

require "spec_helper"

RSpec.describe "GraphQL Parameter Issues Resolution" do
  # Demonstrate the solution to the original query parameter problems

  let(:order_class) do
    Class.new do
      include ActiveShopifyGraphQL::Base
      graphql_type 'Order'
      attribute :id

      # NEW: Explicit parameters required, no unwanted defaults
      connection :line_items, default_arguments: { first: 10 } # No sortKey, no query - won't cause GraphQL errors

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
      attribute :quantity

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

      # NEW: Explicitly specify all parameters you want
      connection :variants, default_arguments: { first: 25, sort_key: 'POSITION', reverse: true }

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

  describe "Problem Resolution: No unwanted GraphQL parameters" do
    it "does not include 'query' parameter for nested connections (fixes original error)" do
      order = order_class.new(id: 1)
      connection_proxy = order.line_items

      # The variables built for the nested connection should not include 'query'
      variables = connection_proxy.send(:build_variables)

      expect(variables).to eq({
                                first: 10
                              })

      # Specifically verify the problematic parameters are not present
      expect(variables).not_to have_key(:query)    # This was causing the original error
      expect(variables).not_to have_key(:sort_key) # This was also problematic for nested connections
    end

    it "does not include 'sortKey' parameter for nested connections (fixes sortKey error)" do
      order = order_class.new(id: 1)
      connection_proxy = order.line_items

      variables = connection_proxy.send(:build_variables)

      # Should not have sortKey which was causing "Field 'lineItems' doesn't accept argument 'sortKey'"
      expect(variables).not_to have_key(:sort_key)
    end

    it "includes only user-specified parameters for root-level connections" do
      product = product_class.new(id: 1)
      connection_proxy = product.variants

      variables = connection_proxy.send(:build_variables)

      # Should include all user-specified parameters plus appropriate root-level parameters
      expect(variables[:first]).to eq(25)
      expect(variables[:sort_key]).to eq('POSITION')
      expect(variables[:reverse]).to be true
    end
  end

  describe "User Experience: Explicit parameter requirements" do
    it "requires developers to specify 'first' parameter explicitly" do
      # Before: connection :orders  # Had default first: 10
      # Now: connection :orders, default_arguments: { first: 10 }  # Must specify explicitly

      connections = order_class.connections
      line_items_config = connections[:line_items]

      expect(line_items_config[:default_arguments][:first]).to eq(10) # User-specified value
    end

    it "allows developers to specify exactly the parameters they want" do
      connections = product_class.connections
      variants_config = connections[:variants]

      # All parameters are exactly as specified by the developer
      expect(variants_config[:default_arguments][:first]).to eq(25)
      expect(variants_config[:default_arguments][:sort_key]).to eq('POSITION')
      expect(variants_config[:default_arguments][:reverse]).to be true
    end

    it "does not apply any unexpected default parameters" do
      connections = order_class.connections
      line_items_config = connections[:line_items]

      # Only user-specified parameters are stored
      expect(line_items_config[:default_arguments][:first]).to eq(10)        # User specified
      expect(line_items_config[:default_arguments][:sort_key]).to be_nil     # Not specified = nil
      expect(line_items_config[:default_arguments][:reverse]).to be_nil      # Not specified = nil
    end
  end

  describe "Backwards Compatibility: Runtime parameter overrides still work" do
    it "allows runtime parameter overrides" do
      order = order_class.new(id: 1)

      # Can still override parameters at runtime
      connection_proxy = order.line_items(first: 5)
      variables = connection_proxy.send(:build_variables)

      expect(variables[:first]).to eq(5) # Runtime override works
      expect(variables).not_to have_key(:query)     # Still no problematic params
      expect(variables).not_to have_key(:sort_key)  # Still no problematic params
    end
  end
end
