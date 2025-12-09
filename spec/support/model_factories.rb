# frozen_string_literal: true

# Factory methods for creating test model classes.
# These provide consistent model definitions across specs without using let blocks.
# Each method creates a fresh class to avoid state bleeding between tests.
module ModelFactories
  module_function

  def build_customer_class(graphql_type: "Customer", with_orders: false, with_addresses: false)
    klass = Class.new do
      include ActiveShopifyGraphQL::Base

      attribute :id
      attribute :email
      attribute :display_name, path: "displayName"

      define_singleton_method(:name) { "Customer" }
      define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "Customer") }
    end

    klass.graphql_type(graphql_type)
    klass.has_many_connected(:orders, default_arguments: { first: 10 }) if with_orders
    klass.has_many_connected(:addresses, default_arguments: { first: 5 }) if with_addresses
    klass
  end

  def build_order_class(graphql_type: "Order", with_line_items: false)
    klass = Class.new do
      include ActiveShopifyGraphQL::Base

      attribute :id
      attribute :name
      attribute :created_at, path: "createdAt", type: :datetime
      attribute :total_price, path: "totalPriceSet.shopMoney.amount"

      define_singleton_method(:name) { "Order" }
      define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "Order") }
    end

    klass.graphql_type(graphql_type)
    klass.has_many_connected(:line_items, default_arguments: { first: 50 }) if with_line_items
    klass
  end

  def build_line_item_class(graphql_type: "LineItem", with_variant: false)
    klass = Class.new do
      include ActiveShopifyGraphQL::Base

      attribute :id
      attribute :quantity

      define_singleton_method(:name) { "LineItem" }
      define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "LineItem") }
    end

    klass.graphql_type(graphql_type)
    klass.has_one_connected(:variant, class_name: "ProductVariant", query_name: "variant") if with_variant
    klass
  end

  def build_product_class(graphql_type: "Product", with_variants: false)
    klass = Class.new do
      include ActiveShopifyGraphQL::Base

      attribute :id
      attribute :title

      define_singleton_method(:name) { "Product" }
      define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "Product") }
    end

    klass.graphql_type(graphql_type)
    klass.has_many_connected(:variants, default_arguments: { first: 10 }) if with_variants
    klass
  end

  def build_product_variant_class(graphql_type: "ProductVariant")
    klass = Class.new do
      include ActiveShopifyGraphQL::Base

      attribute :id
      attribute :sku
      attribute :price

      define_singleton_method(:name) { "ProductVariant" }
      define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "ProductVariant") }
    end

    klass.graphql_type(graphql_type)
    klass
  end

  def build_address_class(graphql_type: "MailingAddress")
    klass = Class.new do
      include ActiveShopifyGraphQL::Base

      attribute :id
      attribute :address1
      attribute :city

      define_singleton_method(:name) { "Address" }
      define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "Address") }
    end

    klass.graphql_type(graphql_type)
    klass
  end

  # Helper to stub multiple constants at once
  def stub_model_constants(example, **models)
    models.each do |name, klass|
      example.stub_const(name.to_s, klass)
    end
  end

  # Build a minimal model class for simple tests
  def build_minimal_model(name:, graphql_type:, attributes: [:id])
    klass = Class.new do
      include ActiveShopifyGraphQL::Base

      define_singleton_method(:name) { name }
      define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, name) }
    end

    klass.graphql_type(graphql_type)
    attributes.each { |attr| klass.attribute(attr) }
    klass
  end
end
