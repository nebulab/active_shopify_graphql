# frozen_string_literal: true

# Factory methods for creating ActiveRecord/PORO test model classes.
module ArPoroModelFactories
  module_function

  # Build a Reward class for testing GraphQLAssociations
  def build_reward_class(with_customer: false, with_variants: false, customer_options: {}, variants_options: {})
    klass = Class.new do
      include ActiveShopifyGraphQL::GraphQLAssociations

      attr_accessor :id, :shopify_customer_id, :shopify_id

      define_singleton_method(:name) { "Reward" }
    end

    klass.belongs_to_graphql(:customer, **customer_options) if with_customer
    klass.has_many_graphql(:variants, class_name: "ProductVariant", **variants_options) if with_variants
    klass
  end

  # Build a test Customer class for GraphQLAssociations (not the GraphQL-backed Customer)
  def build_ar_customer_class(with_orders: false, orders_options: {})
    klass = Class.new do
      include ActiveShopifyGraphQL::GraphQLAssociations

      attr_accessor :id, :shopify_id

      define_singleton_method(:name) { "Customer" }
    end

    klass.has_many_graphql(:orders, class_name: "Order", **orders_options) if with_orders
    klass
  end

  # Build a PlainObject class for testing duck typing compatibility
  def build_plain_object_class(with_customer: false)
    klass = Class.new do
      include ActiveShopifyGraphQL::GraphQLAssociations

      attr_accessor :shopify_customer_id

      define_singleton_method(:name) { "PlainObject" }

      def initialize(shopify_customer_id:)
        @shopify_customer_id = shopify_customer_id
      end
    end

    klass.belongs_to_graphql(:customer) if with_customer
    klass
  end
end
