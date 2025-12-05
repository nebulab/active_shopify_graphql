# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Attributes
    extend ActiveSupport::Concern

    class_methods do
      # @param name [Symbol] The Ruby attribute name
      # @param path [String] The GraphQL field path (auto-inferred if not provided)
      # @param type [Symbol] The type for coercion (:string, :integer, :float, :boolean, :datetime). Arrays are preserved automatically.
      # @param null [Boolean] Whether the attribute can be null (default: true)
      # @param default [Object] Default value to use when the GraphQL response is nil
      # @param transform [Proc] Custom transform block for the value
      def attribute(name, path: nil, type: :string, null: true, default: nil, transform: nil)
        @base_attributes ||= {}

        # Auto-infer GraphQL path for simple cases: display_name -> displayName
        path ||= infer_path(name)

        @base_attributes[name] = {
          path: path,
          type: type,
          null: null,
          default: default,
          transform: transform
        }

        # Create attr_accessor for the attribute
        attr_accessor name unless method_defined?(name) || method_defined?("#{name}=")
      end

      # Get attributes for a specific loader class
      def attributes_for_loader(loader_class)
        base_attrs = @base_attributes || {}
        loader_attrs = @loader_contexts&.dig(loader_class) || {}

        # Merge loader-specific overrides with base attributes
        merged = base_attrs.dup
        loader_attrs.each do |name, overrides|
          merged[name] = if merged[name]
                           merged[name].merge(overrides)
                         else
                           overrides
                         end
        end

        merged
      end

      # Get all base attributes (without loader-specific overrides)
      def base_attributes
        @base_attributes || {}
      end

      private

      # Override attribute method to handle loader context
      def attribute_with_context(name, path: nil, type: :string, null: true, default: nil, transform: nil)
        if @current_loader_context
          # Auto-infer path if not provided
          path ||= infer_path(name)
          @loader_contexts[@current_loader_context][name] = { path: path, type: type, null: null, default: default, transform: transform }
        else
          attribute_without_context(name, path: path, type: type, null: null, default: default, transform: transform)
        end

        # Always create attr_accessor for the attribute on base model
        attr_accessor name unless method_defined?(name) || method_defined?("#{name}=")
      end

      # Alias methods to support context handling
      alias_method :attribute_without_context, :attribute
      alias_method :attribute, :attribute_with_context

      # Infer GraphQL path from Ruby attribute name
      # Only handles simple snake_case to camelCase conversion
      def infer_path(name)
        name.to_s.gsub(/_([a-z])/) { ::Regexp.last_match(1).upcase }
      end
    end
  end
end
