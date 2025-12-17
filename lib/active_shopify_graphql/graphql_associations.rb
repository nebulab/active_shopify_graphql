# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Allows ActiveRecord (or duck-typed) objects to define associations to GraphQL objects
  # This module bridges the gap between local database records and remote Shopify GraphQL data
  #
  # @example
  #   class Reward < ApplicationRecord
  #     include ActiveShopifyGraphQL::GraphQLAssociations
  #
  #     belongs_to_graphql :customer
  #     has_many_graphql :variants, class: "ProductVariant", query_name: "productVariants"
  #   end
  #
  #   reward = Reward.first
  #   customer = reward.customer # => ActiveShopifyGraphQL::Customer instance
  #   variants = reward.variants(first: 10) # => Array of ProductVariant instances
  module GraphQLAssociations
    extend ActiveSupport::Concern

    included do
      class << self
        attr_accessor :graphql_associations
      end

      self.graphql_associations = {}
    end

    class_methods do
      # Define a belongs_to relationship with a GraphQL object
      # Fetches a single GraphQL object using a stored GID or foreign key
      #
      # @param name [Symbol] The association name (e.g., :customer)
      # @param class_name [String] The target GraphQL model class name (defaults to name.to_s.classify)
      # @param foreign_key [Symbol, String] The attribute/column storing the GID or ID (defaults to "shopify_#{name}_id")
      # @param loader_class [Class] Custom loader class (defaults to target class's default_loader)
      #
      # @example Basic usage
      #   belongs_to_graphql :customer
      #   # Expects: shopify_customer_id column with GID like "gid://shopify/Customer/123"
      #
      # @example With custom foreign key
      #   belongs_to_graphql :customer, foreign_key: :customer_gid
      #
      # @example With custom class
      #   belongs_to_graphql :owner, class_name: "Customer"
      def belongs_to_graphql(name, class_name: nil, foreign_key: nil, loader_class: nil)
        association_class_name = class_name || name.to_s.classify
        association_foreign_key = foreign_key || "shopify_#{name}_id"

        # Store association metadata
        graphql_associations[name] = {
          type: :belongs_to,
          class_name: association_class_name,
          foreign_key: association_foreign_key,
          loader_class: loader_class
        }

        # Define the association method
        define_method name do
          return @_graphql_association_cache[name] if @_graphql_association_cache&.key?(name)

          @_graphql_association_cache ||= {}

          # Get the GID or ID value from the foreign key
          gid_or_id = send(association_foreign_key)
          return @_graphql_association_cache[name] = nil if gid_or_id.blank?

          # Resolve the target class
          target_class = association_class_name.constantize

          # Determine which loader to use
          loader = if self.class.graphql_associations[name][:loader_class]
                     self.class.graphql_associations[name][:loader_class].new(target_class)
                   else
                     target_class.default_loader
                   end

          # Load and cache the GraphQL object
          @_graphql_association_cache[name] = target_class.find(gid_or_id, loader: loader)
        end

        # Define setter method for testing/mocking
        define_method "#{name}=" do |value|
          @_graphql_association_cache ||= {}
          @_graphql_association_cache[name] = value
        end
      end

      # Define a has_one relationship with a GraphQL object
      # Fetches a single GraphQL object using a where clause
      #
      # @param name [Symbol] The association name (e.g., :primary_address)
      # @param class_name [String] The target GraphQL model class name (defaults to name.to_s.classify)
      # @param foreign_key [Symbol, String] The attribute on GraphQL objects to filter by (e.g., :customer_id)
      # @param primary_key [Symbol, String] The local attribute to use as filter value (defaults to :id)
      # @param loader_class [Class] Custom loader class (defaults to target class's default_loader)
      #
      # @example Basic usage
      #   has_one_graphql :primary_address, class_name: "Address", foreign_key: :customer_id
      #   customer.primary_address # Returns first Address where customer_id matches
      def has_one_graphql(name, class_name: nil, foreign_key: nil, primary_key: nil, loader_class: nil)
        association_class_name = class_name || name.to_s.classify
        association_primary_key = primary_key || :id
        association_loader_class = loader_class

        # Store association metadata
        graphql_associations[name] = {
          type: :has_one,
          class_name: association_class_name,
          foreign_key: foreign_key,
          primary_key: association_primary_key,
          loader_class: association_loader_class
        }

        # Define the association method
        define_method name do
          return @_graphql_association_cache[name] if @_graphql_association_cache&.key?(name)

          @_graphql_association_cache ||= {}

          # Get primary key value
          primary_key_value = send(association_primary_key)
          return @_graphql_association_cache[name] = nil if primary_key_value.blank?

          # Resolve the target class
          target_class = association_class_name.constantize

          # Determine which loader to use
          loader = if self.class.graphql_associations[name][:loader_class]
                     self.class.graphql_associations[name][:loader_class].new(target_class)
                   else
                     target_class.default_loader
                   end

          # Query with foreign key filter if provided
          result = if self.class.graphql_associations[name][:foreign_key]
                     foreign_key_sym = self.class.graphql_associations[name][:foreign_key]
                     query_conditions = { foreign_key_sym => primary_key_value }
                     target_class.where(query_conditions, loader: loader).first
                   end

          # Cache the result
          @_graphql_association_cache[name] = result
        end

        # Define setter method for testing/mocking
        define_method "#{name}=" do |value|
          @_graphql_association_cache ||= {}
          @_graphql_association_cache[name] = value
        end
      end

      # Define a has_many relationship with GraphQL objects
      # Queries multiple GraphQL objects using a where clause or connection
      #
      # @param name [Symbol] The association name (e.g., :variants)
      # @param class_name [String] The target GraphQL model class name (defaults to name.to_s.classify.singularize)
      # @param query_name [String] The GraphQL query field name (defaults to class_name.pluralize.camelize(:lower))
      # @param foreign_key [Symbol, String] The attribute on GraphQL objects to filter by (e.g., :customer_id)
      # @param primary_key [Symbol, String] The local attribute to use as filter value (defaults to :id)
      # @param loader_class [Class] Custom loader class (defaults to target class's default_loader)
      # @param query_method [Symbol] Method to use for querying (:where or :connection, defaults to :where)
      #
      # @example Basic usage with where query
      #   has_many_graphql :variants, class: "ProductVariant"
      #   reward.variants # Uses where to query
      #
      # @example With custom query_name for a connection
      #   has_many_graphql :line_items, query_name: "lineItems", query_method: :connection
      #   order.line_items(first: 10)
      #
      # @example With filtering by foreign key
      #   has_many_graphql :orders, foreign_key: :customer_id
      #   # Queries orders where customer_id matches the local record's id
      def has_many_graphql(name, class_name: nil, query_name: nil, foreign_key: nil, primary_key: nil, loader_class: nil, query_method: :where)
        association_class_name = class_name || name.to_s.singularize.classify
        association_primary_key = primary_key || :id
        association_loader_class = loader_class
        association_query_method = query_method

        # Auto-determine query_name if not provided
        association_query_name = query_name || name.to_s.camelize(:lower)

        # Store association metadata
        graphql_associations[name] = {
          type: :has_many,
          class_name: association_class_name,
          query_name: association_query_name,
          foreign_key: foreign_key,
          primary_key: association_primary_key,
          loader_class: association_loader_class,
          query_method: association_query_method
        }

        # Define the association method
        define_method name do |**options|
          return @_graphql_association_cache[name] if @_graphql_association_cache&.key?(name) && options.empty?

          @_graphql_association_cache ||= {}

          # Get primary key value
          primary_key_value = send(association_primary_key)
          return @_graphql_association_cache[name] = [] if primary_key_value.blank?

          # Resolve the target class
          target_class = association_class_name.constantize

          # Determine which loader to use
          loader = if self.class.graphql_associations[name][:loader_class]
                     self.class.graphql_associations[name][:loader_class].new(target_class)
                   else
                     target_class.default_loader
                   end

          # Build query based on query_method
          result = if association_query_method == :connection
                     # For connections, we need to handle this differently
                     # This would typically be a nested connection on a parent object
                     # For now, return empty array - real implementation would need parent context
                     []
                   elsif self.class.graphql_associations[name][:foreign_key]
                     # Query with foreign key filter
                     foreign_key_sym = self.class.graphql_associations[name][:foreign_key]
                     query_conditions = { foreign_key_sym => primary_key_value }.merge(options)
                     target_class.where(query_conditions, loader: loader)
                   else
                     # No foreign key specified, just query with provided options
                     target_class.where(options, loader: loader)
                   end

          # Cache if no runtime options provided
          @_graphql_association_cache[name] = result if options.empty?
          result
        end

        # Define setter method for testing/mocking
        define_method "#{name}=" do |value|
          @_graphql_association_cache ||= {}
          @_graphql_association_cache[name] = value
        end
      end
    end
  end
end
