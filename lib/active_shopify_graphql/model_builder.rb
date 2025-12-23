# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Pure factory for building model instances from attribute hashes.
  # Separates data mapping (Loader/ResponseMapper) from object construction.
  #
  # Responsibilities:
  # - Build single model instances from attributes
  # - Apply connection caches to instances
  # - Handle batch building with connection caching
  #
  # @example Single instance
  #   attributes = loader.load_attributes(gid)
  #   customer = ModelBuilder.build(Customer, attributes)
  #
  # @example Batch building
  #   attributes_list = loader.load_paginated_attributes(...)
  #   customers = ModelBuilder.build_many(Customer, attributes_list)
  class ModelBuilder
    class << self
      # Build a single model instance from attributes
      # @param model_class [Class] The model class to instantiate
      # @param attributes [Hash] Attribute hash (may contain :_connection_cache)
      # @return [Object] The instantiated model with cached connections
      def build(model_class, attributes)
        return nil if attributes.nil?

        instance = model_class.new(attributes)
        apply_connection_cache(instance, attributes)
        instance
      end

      # Build multiple model instances from an array of attribute hashes
      # @param model_class [Class] The model class to instantiate
      # @param attributes_array [Array<Hash>] Array of attribute hashes
      # @return [Array<Object>] Array of instantiated models
      def build_many(model_class, attributes_array)
        return [] if attributes_array.nil? || attributes_array.empty?

        attributes_array.filter_map { |attrs| build(model_class, attrs) }
      end

      # Apply connection cache from attributes to an already-instantiated model
      # @param instance [Object] The model instance
      # @param attributes [Hash] Attribute hash that may contain :_connection_cache
      def apply_connection_cache(instance, attributes)
        return unless attributes.is_a?(Hash) && attributes.key?(:_connection_cache)

        instance.instance_variable_set(:@_connection_cache, attributes[:_connection_cache])
      end
    end
  end
end
