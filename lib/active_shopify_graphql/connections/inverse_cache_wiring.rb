# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Connections
    # Single home for the inverse cache wiring logic.
    #
    # When a connection has an +inverse_of+ option, loading records on one side
    # should automatically populate the cache on the other side so the inverse
    # association doesn't trigger an extra round-trip.
    #
    # Two entry points cover the two moments this happens:
    #
    # * +wire_instance+ — the child record is already a model instance (ivar-based cache).
    # * +wire_attributes+ — the child record is still an attributes Hash, about to be
    #   instantiated (Hash-based cache, keyed +:_connection_cache+).
    module InverseCacheWiring
      # Wire the inverse cache on an already-built model instance.
      #
      # @param record [Object] a model instance that is the child side of the connection
      # @param connection_config [Hash] the connection config hash that includes +:inverse_of+
      # @param parent [Object] the parent model instance to store as the cached value
      def self.wire_instance(record, connection_config, parent)
        return unless record && connection_config[:inverse_of]

        inverse_name = connection_config[:inverse_of]
        target_class = connection_config[:class_name].constantize

        return unless target_class.respond_to?(:connections) && target_class.connections[inverse_name]

        inverse_type = target_class.connections[inverse_name][:type]

        record.instance_variable_set(:@_connection_cache, {}) unless record.instance_variable_get(:@_connection_cache)
        cache = record.instance_variable_get(:@_connection_cache)
        cache[inverse_name] = inverse_type == :singular ? parent : [parent]
      end

      # Wire the inverse cache into an attributes Hash before model instantiation.
      #
      # @param attributes [Hash] the attributes hash that will be passed to +model_class.new+
      # @param connection_config [Hash] the connection config hash that includes +:inverse_of+
      # @param parent [Object] the parent model instance to store as the cached value
      def self.wire_attributes(attributes, connection_config, parent)
        return unless attributes.is_a?(Hash) && connection_config[:inverse_of]

        inverse_name = connection_config[:inverse_of]
        target_class = connection_config[:class_name].constantize

        return unless target_class.respond_to?(:connections) && target_class.connections[inverse_name]

        inverse_type = target_class.connections[inverse_name][:type]
        attributes[:_connection_cache] ||= {}
        attributes[:_connection_cache][inverse_name] = inverse_type == :singular ? parent : [parent]
      end
    end
  end
end
