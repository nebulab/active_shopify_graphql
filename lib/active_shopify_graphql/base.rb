# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Base
    extend ActiveSupport::Concern

    included do
      include ActiveModel::AttributeAssignment
      include ActiveModel::Validations
      extend ActiveModel::Naming
      include ActiveShopifyGraphQL::Model::GraphqlTypeResolver
      include ActiveShopifyGraphQL::Model::FinderMethods
      include ActiveShopifyGraphQL::Model::Associations
      include ActiveShopifyGraphQL::Model::Connections
      include ActiveShopifyGraphQL::Model::Attributes
      include ActiveShopifyGraphQL::Model::MetafieldAttributes
      include ActiveShopifyGraphQL::Model::LoaderSwitchable
    end

    def initialize(attributes = {})
      super()

      # Extract connection cache if present and populate inverse caches
      if attributes.key?(:_connection_cache)
        @_connection_cache = attributes.delete(:_connection_cache)
        populate_inverse_caches_on_initialization
      end

      assign_attributes(attributes)
    end

    private

    def populate_inverse_caches_on_initialization
      return unless @_connection_cache

      @_connection_cache.each do |connection_name, records|
        connection_config = self.class.connections[connection_name]
        next unless connection_config && connection_config[:inverse_of]

        inverse_name = connection_config[:inverse_of]
        records_array = Array(records).compact

        records_array.each do |record|
          next unless record.respond_to?(:instance_variable_set)

          record.instance_variable_set(:@_connection_cache, {}) unless record.instance_variable_get(:@_connection_cache)
          cache = record.instance_variable_get(:@_connection_cache)

          # Determine the type of the inverse connection
          next unless record.class.respond_to?(:connections) && record.class.connections[inverse_name]

          inverse_type = record.class.connections[inverse_name][:type]
          cache[inverse_name] =
            if inverse_type == :singular
              self
            else
              # For collection inverses, wrap parent in an array
              [self]
            end
        end
      end
    end
  end
end
