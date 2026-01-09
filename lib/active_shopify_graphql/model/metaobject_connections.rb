# frozen_string_literal: true

module ActiveShopifyGraphQL::Model::MetaobjectConnections
  extend ActiveSupport::Concern

  included do
    class << self
      def metaobject_connections
        @metaobject_connections ||=
          if superclass.respond_to?(:metaobject_connections)
            superclass.metaobject_connections.dup
          else
            {}
          end
      end

      attr_writer :metaobject_connections
    end
  end

  class_methods do
    def has_one_connected_metaobject(name, class_name: nil, source_namespace: "custom", source_key: nil)
      connection_class_name = class_name || name.to_s.classify
      metafield_key = source_key || name.to_s.underscore

      metaobject_connections[name] = {
        class_name: connection_class_name,
        source_namespace: source_namespace,
        source_key: metafield_key,
        type: :metaobject_connection
      }

      metafield_alias = "#{name.to_s.camelize(:lower)}Metafield"

      define_method name do
        return @_connection_cache[name] if @_connection_cache&.key?(name)

        metafield_value = instance_variable_get("@#{metafield_alias}")
        return nil unless metafield_value

        reference = metafield_value["reference"]
        return nil unless reference

        gid = reference["id"]
        return nil unless gid

        target_class = connection_class_name.constantize
        attributes = target_class.default_loader.load_attributes(gid)

        return nil unless attributes

        instance = target_class.new(attributes)

        @_connection_cache ||= {}
        @_connection_cache[name] = instance
      end

      define_method "#{name}=" do |value|
        @_connection_cache ||= {}
        @_connection_cache[name] = value
      end
    end
  end
end
