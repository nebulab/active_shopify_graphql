# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Model
    module MetafieldAttributes
      extend ActiveSupport::Concern

      class_methods do
        # Define a metafield attribute for this model.
        #
        # @param name [Symbol] The Ruby attribute name
        # @param namespace [String] The metafield namespace
        # @param key [String] The metafield key
        # @param type [Symbol] The type for coercion (:string, :integer, :float, :boolean, :datetime, :json)
        # @param null [Boolean] Whether the attribute can be null (default: true)
        # @param default [Object] Default value when GraphQL response is nil
        # @param transform [Proc] Custom transform block for the value
        def metafield_attribute(name, namespace:, key:, type: :string, null: true, default: nil, transform: nil)
          @metafields ||= {}
          @metafields[name] = { namespace: namespace, key: key, type: type }

          # Build metafield config
          alias_name = "#{infer_path(name)}Metafield"
          value_field = type == :json ? 'jsonValue' : 'value'
          path = "#{alias_name}.#{value_field}"

          config = {
            path: path,
            type: type,
            null: null,
            default: default,
            transform: transform,
            is_metafield: true,
            metafield_alias: alias_name,
            metafield_namespace: namespace,
            metafield_key: key
          }

          if @current_loader_context
            @loader_contexts[@current_loader_context][name] = config
          else
            @base_attributes ||= {}
            @base_attributes[name] = config
          end

          attr_accessor name unless method_defined?(name) || method_defined?("#{name}=")
        end

        # Get metafields defined for this model
        def metafields
          @metafields || {}
        end

        private

        # Infer GraphQL path from Ruby attribute name (delegates to Attributes if available)
        def infer_path(name)
          name.to_s.gsub(/_([a-z])/) { ::Regexp.last_match(1).upcase }
        end
      end
    end
  end
end
