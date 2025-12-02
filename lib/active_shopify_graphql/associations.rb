# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Associations
    extend ActiveSupport::Concern

    included do
      class << self
        attr_accessor :associations
      end

      self.associations = {}
    end

    class_methods do
      def has_many(name, class_name: nil, foreign_key: nil, primary_key: nil)
        association_class_name = class_name || name.to_s.classify
        association_foreign_key = foreign_key || "shopify_#{model_name.element.downcase}_id"
        association_primary_key = primary_key || :id

        # Store association metadata
        associations[name] = {
          type: :has_many,
          class_name: association_class_name,
          foreign_key: association_foreign_key,
          primary_key: association_primary_key
        }

        # Define the association method
        define_method name do
          return @_association_cache[name] if @_association_cache&.key?(name)

          @_association_cache ||= {}

          primary_key_value = send(association_primary_key)
          return @_association_cache[name] = [] if primary_key_value.blank?

          # Extract numeric ID from Shopify GID if needed
          primary_key_value = primary_key_value.to_plain_id if primary_key_value.gid?

          association_class = association_class_name.constantize
          @_association_cache[name] = association_class.where(association_foreign_key => primary_key_value)
        end

        # Define the association setter method for testing/mocking
        define_method "#{name}=" do |value|
          @_association_cache ||= {}
          @_association_cache[name] = value
        end
      end

      def has_one(name, class_name: nil, foreign_key: nil, primary_key: nil)
        association_class_name = class_name || name.to_s.classify
        association_foreign_key = foreign_key || "shopify_#{model_name.element.downcase}_id"
        association_primary_key = primary_key || :id

        # Store association metadata
        associations[name] = {
          type: :has_one,
          class_name: association_class_name,
          foreign_key: association_foreign_key,
          primary_key: association_primary_key
        }

        # Define the association method
        define_method name do
          return @_association_cache[name] if @_association_cache&.key?(name)

          @_association_cache ||= {}

          primary_key_value = send(association_primary_key)
          return @_association_cache[name] = nil if primary_key_value.blank?

          # Extract numeric ID from Shopify GID if needed
          primary_key_value = primary_key_value.to_plain_id if primary_key_value.gid?

          association_class = association_class_name.constantize
          @_association_cache[name] = association_class.find_by(association_foreign_key => primary_key_value)
        end

        # Define the association setter method for testing/mocking
        define_method "#{name}=" do |value|
          @_association_cache ||= {}
          @_association_cache[name] = value
        end
      end
    end
  end
end
