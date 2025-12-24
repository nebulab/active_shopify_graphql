# frozen_string_literal: true

module ActiveShopifyGraphQL::Model::MetaobjectConnections
  extend ActiveSupport::Concern

  class_methods do
    # Define a connection to a Metaobject via a metafield reference
    # @param name [Symbol] The connection name (e.g., :provider)
    # @param class_name [String] The target metaobject class name (defaults to name.to_s.classify)
    # @param namespace [String] The metafield namespace (defaults to "custom")
    # @param key [String] The metafield key (defaults to connection name)
    # @param eager_load [Boolean] Whether to automatically eager load this connection (default: false)
    # @param inverse_of [Symbol] The name of the inverse connection on the target model (optional)
    def has_one_connected_metaobject(name, class_name: nil, namespace: "custom", key: nil, eager_load: false, inverse_of: nil)
      connection_class_name = class_name || name.to_s.classify
      metafield_key = key || name.to_s

      # Store connection metadata
      connections[name] = {
        class_name: connection_class_name,
        type: :metaobject_reference,
        metafield_namespace: namespace,
        metafield_key: metafield_key,
        eager_load: eager_load,
        inverse_of: inverse_of,
        original_name: name
      }

      # Define the connection method
      define_method name do
        # Check if this connection was eager loaded
        return @_connection_cache[name] if @_connection_cache&.key?(name)

        # Lazy load not yet implemented for metaobject connections
        # Would require querying metafield first, getting GID, then querying metaobject
        raise NotImplementedError, "Lazy loading for metaobject connections not yet implemented. Use includes(:#{name}) to eager load."
      end

      # Define setter method for testing/caching
      define_method "#{name}=" do |value|
        @_connection_cache ||= {}
        @_connection_cache[name] = value
      end
    end
  end
end
