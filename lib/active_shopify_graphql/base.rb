# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Base
    extend ActiveSupport::Concern

    included do
      include ActiveModel::AttributeAssignment
      include ActiveModel::Validations
      extend ActiveModel::Naming
      include ActiveShopifyGraphQL::FinderMethods
      include ActiveShopifyGraphQL::Associations
      include ActiveShopifyGraphQL::Connections
      include ActiveShopifyGraphQL::LoaderSwitchable
    end

    def initialize(attributes = {})
      super()
      assign_attributes(attributes)
    end
  end
end
