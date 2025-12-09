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
      def has_one_connected(name, **options)
        connection(name, type: :singular, **options)
      end

      # Define a plural connection (returns a collection via edges)
      # @see #connection
      def has_many_connected(name, **options)
        connection(name, type: :connection, **options)
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
      def connection(name, class_name: nil, query_name: nil, foreign_key: nil, loader_class: nil, eager_load: false, type: :connection, default_arguments: {})
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
          default_arguments: default_arguments
        }

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
        auto_included_connections = []
        auto_included_connections = connections.select { |_name, config| config[:eager_load] }.keys if respond_to?(:connections)

        # Merge manual and automatic connections
        all_included_connections = (connection_names + auto_included_connections).uniq

        # Create a new class that inherits from self with eager loading enabled
        included_class = Class.new(self)

        # Store the connections to include
        included_class.instance_variable_set(:@included_connections, all_included_connections)

        # Override methods to use eager loading
        included_class.define_singleton_method(:default_loader) do
          @default_loader ||= superclass.default_loader.class.new(
            superclass,
            included_connections: @included_connections
          )
        end

        # Preserve the original class name and model name for GraphQL operations
        included_class.define_singleton_method(:name) { superclass.name }
        included_class.define_singleton_method(:model_name) { superclass.model_name }
        included_class.define_singleton_method(:connections) { superclass.connections }

        included_class
      end

      private

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
  end
end
