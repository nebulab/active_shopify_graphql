# frozen_string_literal: true

require_relative "connections/connection_proxy"

module ActiveShopifyGraphQL
  module Connections
    extend ActiveSupport::Concern

    included do
      class << self
        attr_accessor :connections
      end

      self.connections = {}
    end

    class_methods do
      # Define a singular connection (returns a single object)
      # @see #connection
      def has_one_connected(name, inverse_of: nil, **options)
        connection(name, type: :singular, inverse_of: inverse_of, **options)
      end

      # Define a plural connection (returns a collection via edges)
      # @see #connection
      def has_many_connected(name, inverse_of: nil, **options)
        connection(name, type: :connection, inverse_of: inverse_of, **options)
      end

      # Define a GraphQL connection to another ActiveShopifyGraphQL model
      # @param name [Symbol] The connection name (e.g., :orders)
      # @param class_name [String] The target model class name (defaults to name.to_s.classify)
      # @param query_name [String] The GraphQL query field name (auto-determined based on nested/root-level)
      # @param foreign_key [String] The field to filter by (auto-determined for root-level queries)
      # @param loader_class [Class] Custom loader class to use (defaults to model's default loader)
      # @param eager_load [Boolean] Whether to automatically eager load this connection (default: false)
      # @param type [Symbol] The type of connection (:connection, :singular). Default is :connection.
      # @param default_arguments [Hash] Default arguments to pass to the GraphQL query (e.g. first: 10)
      # @param inverse_of [Symbol] The name of the inverse connection on the target model (optional)
      def connection(name, class_name: nil, query_name: nil, foreign_key: nil, loader_class: nil, eager_load: false, type: :connection, default_arguments: {}, inverse_of: nil)
        # Infer defaults
        connection_class_name = class_name || name.to_s.classify

        # Set query_name - default to camelCase for nested fields
        connection_query_name = query_name || name.to_s.camelize(:lower)

        connection_loader_class = loader_class

        # Store connection metadata
        connections[name] = {
          class_name: connection_class_name,
          query_name: connection_query_name,
          foreign_key: foreign_key,
          loader_class: connection_loader_class,
          eager_load: eager_load,
          type: type,
          nested: true, # Always treated as nested (accessed via parent field)
          target_class_name: connection_class_name,
          original_name: name,
          default_arguments: default_arguments,
          inverse_of: inverse_of
        }

        # Validate inverse relationship if specified (validation is deferred to runtime)
        validate_inverse_of!(name, connection_class_name, inverse_of) if inverse_of

        # Define the connection method that returns a proxy
        define_method name do |**options|
          # Check if this connection was eager loaded
          return @_connection_cache[name] if @_connection_cache&.key?(name)

          config = self.class.connections[name]
          if config[:type] == :singular
            # Lazy load singular association
            loader_class = config[:loader_class] || self.class.default_loader.class
            target_class = config[:class_name].constantize
            loader = loader_class.new(target_class)

            # Load the record
            records = loader.load_connection_records(config[:query_name], options, self, config)

            # Populate inverse cache if inverse_of is specified
            populate_inverse_cache_for_connection(records, config, self)

            # Cache it
            @_connection_cache ||= {}
            @_connection_cache[name] = records
            records
          elsif options.empty?
            # If no runtime options are provided, reuse existing proxy if it exists
            @_connection_proxies ||= {}
            @_connection_proxies[name] ||= ConnectionProxy.new(
              parent: self,
              connection_name: name,
              connection_config: self.class.connections[name],
              options: options
            )
          else
            # Create a new proxy for custom options (don't cache these)
            ConnectionProxy.new(
              parent: self,
              connection_name: name,
              connection_config: self.class.connections[name],
              options: options
            )
          end
        end

        # Define setter method for testing/caching
        define_method "#{name}=" do |value|
          @_connection_cache ||= {}
          @_connection_cache[name] = value
        end
      end

      # Load records with eager-loaded connections
      # @param *connection_names [Symbol, Hash] The connection names to eager load
      # @return [Class] A modified class for method chaining
      #
      # @example
      #   Customer.includes(:orders).find(123)
      #   Customer.includes(:orders, :addresses).where(email: "john@example.com")
      #   Order.includes(line_items: :variant)
      def includes(*connection_names)
        # Validate connections exist
        validate_includes_connections!(connection_names)

        # Collect connections with eager_load: true
        auto_included_connections = connections.select { |_name, config| config[:eager_load] }.keys

        # Merge manual and automatic connections
        all_included_connections = (connection_names + auto_included_connections).uniq

        # Create a scope object that holds the included connections
        IncludesScope.new(self, all_included_connections)
      end

      private

      def validate_inverse_of!(_name, _target_class_name, _inverse_name)
        # Validation is deferred until runtime when connections are actually used
        # This allows class definitions to be in any order
        # The validation logic will be checked when inverse cache is populated
        nil
      end

      def validate_includes_connections!(connection_names)
        connection_names.each do |name|
          if name.is_a?(Hash)
            name.each do |key, value|
              raise ArgumentError, "Invalid connection for #{self.name}: #{key}. Available connections: #{connections.keys.join(', ')}" unless connections.key?(key.to_sym)

              # Recursively validate nested connections
              target_class = connections[key.to_sym][:class_name].constantize
              if target_class.respond_to?(:validate_includes_connections!, true)
                nested_names = value.is_a?(Array) ? value : [value]
                target_class.send(:validate_includes_connections!, nested_names)
              end
            end
          else
            raise ArgumentError, "Invalid connection for #{self.name}: #{name}. Available connections: #{connections.keys.join(', ')}" unless connections.key?(name.to_sym)
          end
        end
      end
    end

    # Instance method to populate inverse cache for lazy-loaded connections

    def populate_inverse_cache_for_connection(records, connection_config, parent)
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
