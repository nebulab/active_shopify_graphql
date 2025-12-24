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

        # Lazy load the metaobject connection (fetches all data in one query)
        config = self.class.connections[name]
        target_class = config[:class_name].constantize

        # Query for the full metaobject data in one go
        metaobject = lazy_load_metaobject_reference(config, target_class)

        # Cache and return
        @_connection_cache ||= {}
        @_connection_cache[name] = metaobject
        metaobject
      end

      # Define setter method for testing/caching
      define_method "#{name}=" do |value|
        @_connection_cache ||= {}
        @_connection_cache[name] = value
      end
    end
  end

  # Instance method to lazy-load metaobject reference with full data in one query
  def lazy_load_metaobject_reference(connection_config, target_class)
    # Validate that the parent record has an id or gid
    unless (respond_to?(:id) && id.present?) || (respond_to?(:gid) && gid.present?)
      raise ArgumentError, "Cannot lazy load metaobject connection on #{self.class.name} without an id or gid. " \
                           "Ensure the 'id' or 'gid' attribute is defined and loaded."
    end

    # Build query to fetch full metaobject data
    namespace = connection_config[:metafield_namespace]
    key = connection_config[:metafield_key]

    graphql_type = self.class.graphql_type_for_loader(self.class.default_loader.class)
    query_name = graphql_type.camelize(:lower)

    # Build metaobject field queries
    metaobject_fields = build_metaobject_field_queries(target_class)

    query = <<~GRAPHQL
      query getMetafieldReference($id: ID!) {
        #{query_name}(id: $id) {
          metafield(namespace: "#{namespace}", key: "#{key}") {
            reference {
              ... on Metaobject {
                id
                handle
                type
                displayName
                #{metaobject_fields}
              }
            }
          }
        }
      }
    GRAPHQL

    # Execute the query
    loader = self.class.default_loader
    # Use gid if available, otherwise normalize the numeric id
    parent_id = if respond_to?(:gid) && gid.present?
                  gid
                else
                  ActiveShopifyGraphQL::GidHelper.normalize_gid(id, graphql_type)
                end
    response = loader.perform_graphql_query(query, id: parent_id)

    # Extract the metaobject data from the response
    metaobject_data = response.dig("data", query_name, "metafield", "reference")
    return nil unless metaobject_data

    # Build the metaobject instance
    build_metaobject_from_data(metaobject_data, target_class)
  end

  private

  # Build GraphQL field queries for metaobject attributes
  def build_metaobject_field_queries(target_class)
    return "" unless target_class.respond_to?(:metaobject_attributes)

    target_class.metaobject_attributes.map do |_attr_name, config|
      field_key = config[:key]
      aliased_key = field_key.gsub(/[^a-zA-Z0-9_]/, '_')
      # Only query the value field we actually need based on type
      value_field = config[:type] == :json ? 'jsonValue' : 'value'
      "#{aliased_key}: field(key: \"#{field_key}\") { #{value_field} }"
    end.join("\n")
  end

  # Build metaobject instance from GraphQL response data
  def build_metaobject_from_data(data, target_class)
    attributes = {
      id: data["id"],
      handle: data["handle"],
      type: data["type"],
      display_name: data["displayName"]
    }

    # Map metaobject fields to model attributes
    target_class.metaobject_attributes.each do |attr_name, config|
      field_key = config[:key]
      aliased_key = field_key.gsub(/[^a-zA-Z0-9_]/, '_')
      field_data = data[aliased_key]

      next unless field_data

      # Extract value based on type
      value = if config[:type] == :json
                field_data["jsonValue"]
              else
                field_data["value"]
              end

      # Apply type coercion
      value = coerce_metaobject_value(value, config[:type]) if value

      # Apply transform if provided
      value = config[:transform].call(value) if config[:transform] && value

      attributes[attr_name] = value || config[:default]
    end

    target_class.new(attributes)
  end

  # Coerce metaobject field values to the specified type
  def coerce_metaobject_value(value, type)
    case type
    when :integer
      value.to_i
    when :float
      value.to_f
    when :boolean
      [true, "true"].include?(value)
    when :datetime
      begin
        Time.parse(value)
      rescue ArgumentError
        value
      end
    when :json
      value # Already parsed by GraphQL
    else
      value.to_s
    end
  end
end
