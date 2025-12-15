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

      def inspect
        ensure_loaded
        @records.inspect
      end

      def pretty_print(q)
        ensure_loaded
        @records.pretty_print(q)
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

        # Populate inverse cache if inverse_of is specified
        populate_inverse_cache(@records, @connection_config, @parent)

        @loaded = true
      end

      def build_variables
        default_args = @connection_config[:default_arguments] || {}
        default_args.merge(@options).compact
      end

      def populate_inverse_cache(records, connection_config, parent)
        return unless connection_config[:inverse_of]
        return if records.nil? || (records.is_a?(Array) && records.empty?)

        inverse_name = connection_config[:inverse_of]
        target_class = connection_config[:class_name].constantize

        # Ensure target class has the inverse connection defined
        return unless target_class.respond_to?(:connections) && target_class.connections[inverse_name]

        inverse_type = target_class.connections[inverse_name][:type]
        records_array = records.is_a?(Array) ? records : [records]

        records_array.each do |record|
          next unless record

          record.instance_variable_set(:@_connection_cache, {}) unless record.instance_variable_get(:@_connection_cache)
          cache = record.instance_variable_get(:@_connection_cache)

          cache[inverse_name] =
            if inverse_type == :singular
              parent
            else
              # For collection inverses, wrap parent in an array
              [parent]
            end
        end
      end
    end
  end
end
