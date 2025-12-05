# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Connections
    # Connection proxy class for lazy loading
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

      # Enumerate over connection records (loads if not loaded)
      def each(&block)
        load_records unless @loaded
        @records.each(&block)
      end

      # Return connection records as array (loads if not loaded)
      def to_a
        load_records unless @loaded
        @records.dup
      end

      # Check if connection is loaded
      def loaded?
        @loaded
      end

      # Get the count of records (loads if not loaded)
      def size
        to_a.size
      end
      alias length size
      alias count size

      # Check if connection is empty (loads if not loaded)
      def empty?
        to_a.empty?
      end

      # Get first record (loads if not loaded)
      def first(n = nil)
        records = to_a
        n ? records.first(n) : records.first
      end

      # Get last record (loads if not loaded)
      def last(n = nil)
        records = to_a
        n ? records.last(n) : records.last
      end

      # Enable array-like access
      def [](index)
        to_a[index]
      end

      # Reload the connection
      def reload
        @loaded = false
        @records = nil
        self
      end

      private

      def load_records
        return if @loaded

        # Get the loader class from connection config or parent model
        loader_class = @connection_config[:loader_class] || @parent.class.default_loader.class

        # Get the target model class
        target_class = @connection_config[:class_name].constantize

        # Create loader instance for the target model
        loader = loader_class.new(target_class)

        # Build the GraphQL variables for the connection query
        variables = build_connection_variables

        # Execute the connection query
        @records = loader.load_connection_records(
          @connection_config[:query_name],
          variables,
          @parent,
          @connection_config
        )

        # Ensure @records is always an array for consistency (never nil)
        @records = [] if @records.nil?

        @loaded = true
        @records
      end

      def build_connection_variables
        # Merge connection default arguments with runtime options
        default_args = @connection_config[:default_arguments] || {}
        options = default_args.merge(@options)

        # Passthrough all arguments except 'query' which needs special handling
        # Transform keys to camelCase for GraphQL
        variables = {}
        options.each do |key, value|
          # Skip nil values
          next if value.nil?

          # Pass through all values directly - no special treatment
          variables[key] = value
        end

        variables
      end
    end
  end
end
