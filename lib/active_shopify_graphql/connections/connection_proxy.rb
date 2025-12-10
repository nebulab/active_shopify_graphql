# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Connections
    # Lazy-loading proxy for GraphQL connections.
    # Implements Enumerable and delegates to the loaded records array.
    class ConnectionProxy
      include Enumerable

      def initialize(parent:, connection_name:, connection_config:, options:)
        @parent = parent
        @connection_name = connection_name
        @connection_config = connection_config
        @options = options
        @loaded = false
        @records = nil
      end

      # Core Enumerable method - all others derive from this
      def each(&block)
        ensure_loaded
        @records.each(&block)
      end

      # Array coercion (returns a copy to prevent mutation)
      def to_a
        ensure_loaded
        @records.dup
      end
      alias to_ary to_a

      def loaded?
        @loaded
      end

      def load
        ensure_loaded
        self
      end

      # Override for efficiency - avoids full iteration
      def size
        ensure_loaded
        @records.size
      end
      alias length size
      alias count size

      # Override for efficiency
      def empty?
        ensure_loaded
        @records.empty?
      end

      # Override first/last for efficiency (avoid iterating entire collection)
      def first(n = nil)
        ensure_loaded
        n ? @records.first(n) : @records.first
      end

      def last(n = nil)
        ensure_loaded
        n ? @records.last(n) : @records.last
      end

      def [](index)
        ensure_loaded
        @records[index]
      end

      def reload
        @loaded = false
        @records = nil
        self
      end

      private

      def ensure_loaded
        return if @loaded

        loader_class = @connection_config[:loader_class] || @parent.class.default_loader.class
        target_class = @connection_config[:class_name].constantize
        loader = loader_class.new(target_class)

        @records = loader.load_connection_records(
          @connection_config[:query_name],
          build_variables,
          @parent,
          @connection_config
        ) || []

        @loaded = true
      end

      def build_variables
        default_args = @connection_config[:default_arguments] || {}
        default_args.merge(@options).compact
      end
    end
  end
end
