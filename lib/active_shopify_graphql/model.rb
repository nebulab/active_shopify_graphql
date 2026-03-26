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

        Array(records).compact.each do |record|
          ActiveShopifyGraphQL::Connections::InverseCacheWiring.wire_instance(record, connection_config, self)
        end
      end
    end
  end
end
