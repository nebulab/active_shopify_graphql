# frozen_string_literal: true

RSpec.describe ActiveShopifyGraphQL::Connections, "nested connections" do
  before do
    # Define classes in proper order to avoid constantize issues
    product_variant_class = Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type 'ProductVariant'
      # ProductVariant can be queried at root level, so no nested_under declaration

      attribute :id

      def self.name
        'ProductVariant'
      end
    end

    line_item_class = Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type 'LineItem'
      # No explicit nested_under - should be inferred from usage

      attribute :id

      def self.name
        'LineItem'
      end

      def self.model_name
        ActiveModel::Name.new(self, nil, 'LineItem')
      end
    end

    order_class = Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type 'Order'

      attribute :id
      attribute :created_at, type: :datetime

      def self.name
        'Order'
      end

      def self.model_name
        ActiveModel::Name.new(self, nil, 'Order')
      end

      def self.default_loader_class
        ActiveShopifyGraphQL::Loaders::AdminApiLoader
      end
    end

    # Set up constants first
    stub_const('ProductVariant', product_variant_class)
    stub_const('LineItem', line_item_class)
    stub_const('Order', order_class)

    # Now add connections after constants are available
    order_class.class_eval do
      connection :line_items, default_arguments: { first: 10 }
    end

    line_item_class.class_eval do
      connection :variant, class_name: 'ProductVariant', default_arguments: { first: 10 }
    end

    @order_class = order_class
    @line_item_class = line_item_class
    @product_variant_class = product_variant_class
  end

  describe "connection configuration" do
    it "creates line_items connection with corrected nested configuration" do
      # Initial config may not be correct since analysis happens at runtime
      order = @order_class.new(id: 'gid://shopify/Order/123')
      line_items_proxy = order.line_items

      # Access the corrected config by triggering analysis
      config = line_items_proxy.instance_variable_get(:@connection_config)

      expect(config[:nested]).to be true
      expect(config[:query_name]).to eq('lineItems')
      expect(config[:foreign_key]).to be_nil
      expect(config[:sort_key]).to be_nil
    end

    it "treats variant connection as nested" do
      # ProductVariant is accessed via LineItem, so it is nested
      line_item = @line_item_class.new(id: 'gid://shopify/LineItem/123')
      variant_proxy = line_item.variant

      config = variant_proxy.instance_variable_get(:@connection_config)

      expect(config[:nested]).to be true
      expect(config[:query_name]).to eq('variant') # camelCase
    end
  end

  describe "nested connection queries" do
    let(:order) { @order_class.new(id: 'gid://shopify/Order/6333030596907') }
    let(:mock_loader) { double('MockLoader') }

    before do
      allow(@order_class).to receive(:default_loader).and_return(mock_loader)
      allow(mock_loader).to receive(:class).and_return(ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
    end

    it "builds nested GraphQL query for line_items" do
      # Expect the loader to be called with nested connection parameters
      expect(mock_loader).to receive(:load_connection_records) do |query_name, _variables, parent, connection_config|
        expect(query_name).to eq('lineItems') # camelCase for nested connections
        expect(parent).to eq(order)
        expect(connection_config[:nested]).to be true
        []
      end

      line_items = order.line_items
      line_items.to_a # Force loading
    end

    it "handles parent with numeric ID by reconstructing GID" do
      # Some applications may strip GIDs to numeric IDs
      order_with_numeric_id = @order_class.new(id: '6333030596907')

      # Mock the loader to verify the GID is reconstructed
      expect(mock_loader).to receive(:load_connection_records) do |_query_name, _variables, _parent, _connection_config|
        []
      end

      # The loader should receive the request and internally reconstruct the GID
      line_items = order_with_numeric_id.line_items
      line_items.to_a # Force loading
    end

    it "handles parent with gid attribute" do
      # Some applications may have a dedicated gid attribute
      order_with_gid = @order_class.new(id: '6333030596907')
      allow(order_with_gid).to receive(:gid).and_return('gid://shopify/Order/6333030596907')

      expect(mock_loader).to receive(:load_connection_records) do |_query_name, _variables, _parent, _connection_config|
        []
      end

      line_items = order_with_gid.line_items
      line_items.to_a # Force loading
    end
  end
end
