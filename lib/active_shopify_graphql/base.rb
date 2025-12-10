# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Base
    extend ActiveSupport::Concern

    included do
      include ActiveModel::AttributeAssignment
      include ActiveModel::Validations
      extend ActiveModel::Naming
      include ActiveShopifyGraphQL::GraphqlTypeResolver
      include ActiveShopifyGraphQL::FinderMethods
      include ActiveShopifyGraphQL::Associations
      include ActiveShopifyGraphQL::Connections
      include ActiveShopifyGraphQL::Attributes
      include ActiveShopifyGraphQL::MetafieldAttributes
      include ActiveShopifyGraphQL::LoaderSwitchable
    end

    def initialize(attributes = {})
      super()

      # Extract connection cache if present
      @_connection_cache = attributes.delete(:_connection_cache) if attributes.key?(:_connection_cache)

      assign_attributes(attributes)
    end
  end
end
