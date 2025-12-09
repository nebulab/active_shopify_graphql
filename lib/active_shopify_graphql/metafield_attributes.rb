# frozen_string_literal: true

module ActiveShopifyGraphQL
  module MetafieldAttributes
    extend ActiveSupport::Concern

    class_methods do
      # Define a metafield attribute for this model
      # @param name [Symbol] The Ruby attribute name
      # @param namespace [String] The metafield namespace
      # @param key [String] The metafield key
      # @param type [Symbol] The type for coercion (:string, :integer, :float, :boolean, :datetime, :json). Arrays are preserved automatically.
      # @param null [Boolean] Whether the attribute can be null (default: true)
      # @param default [Object] Default value to use when the GraphQL response is nil
      # @param transform [Proc] Custom transform block for the value
      def metafield_attribute(name, namespace:, key:, type: :string, null: true, default: nil, transform: nil)
        @base_attributes ||= {}
        @metafields ||= {}

        # Store metafield metadata for special handling
        @metafields[name] = {
          namespace: namespace,
          key: key,
          type: type
        }

        # Generate alias and path for metafield - use camelCase for GraphQL
        alias_name = "#{infer_path(name)}Metafield"
        value_field = type == :json ? 'jsonValue' : 'value'
        path = "#{alias_name}.#{value_field}"

        @base_attributes[name] = {
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

        # Create attr_accessor for the attribute
        attr_accessor name unless method_defined?(name) || method_defined?("#{name}=")
      end

      # Get metafields defined for this model
      def metafields
        @metafields || {}
      end

      private

      # Override metafield_attribute method to handle loader context
      def metafield_attribute_with_context(name, **options)
        if @current_loader_context
          # For loader-specific metafields, we need to generate the full config
          namespace = options[:namespace]
          key = options[:key]
          type = options[:type] || :string

          alias_name = "#{infer_path(name)}Metafield"
          value_field = type == :json ? 'jsonValue' : 'value'
          path = "#{alias_name}.#{value_field}"

          @loader_contexts[@current_loader_context][name] = {
            path: path,
            type: type,
            null: options[:null] || true,
            default: options[:default],
            transform: options[:transform],
            is_metafield: true,
            metafield_alias: alias_name,
            metafield_namespace: namespace,
            metafield_key: key
          }
        else
          metafield_attribute_without_context(name, **options)
        end
      end

      # Alias methods to support context handling
      alias_method :metafield_attribute_without_context, :metafield_attribute
      alias_method :metafield_attribute, :metafield_attribute_with_context
    end
  end
end
