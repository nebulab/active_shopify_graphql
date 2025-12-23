# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Base class for all GraphQL-backed models.
  #
  # Models should inherit from this class (typically via an ApplicationShopifyGqlRecord
  # intermediate class) to gain ActiveRecord-like functionality for Shopify GraphQL APIs.
  #
  # @example Creating an ApplicationShopifyGqlRecord base class
  #   class ApplicationShopifyGqlRecord < ActiveShopifyGraphQL::Model
  #     attribute :id, transform: ->(id) { id.split("/").last }
  #     attribute :gid, path: "id"
  #   end
  #
  # @example Defining a model
  #   class Customer < ApplicationShopifyGqlRecord
  #     graphql_type "Customer"
  #
  #     attribute :first_name
  #     attribute :email, path: "defaultEmailAddress.emailAddress"
  #   end
  #
  class Model
    include ActiveModel::AttributeAssignment
    include ActiveModel::Validations
    extend ActiveModel::Naming

    include GraphqlTypeResolver
    include FinderMethods
    include Associations
    include Connections
    include Attributes
    include MetafieldAttributes
    include LoaderSwitchable

    def initialize(attributes = {})
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
