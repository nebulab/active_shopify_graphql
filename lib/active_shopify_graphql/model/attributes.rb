# frozen_string_literal: true

module ActiveShopifyGraphQL::Model::Attributes
  extend ActiveSupport::Concern

  class_methods do
    # Define an attribute with automatic GraphQL path inference and type coercion.
    #
    # @param name [Symbol] The Ruby attribute name
    # @param path [String] The GraphQL field path (auto-inferred if not provided)
    # @param type [Symbol] The type for coercion (:string, :integer, :float, :boolean, :datetime)
    # @param null [Boolean] Whether the attribute can be null (default: true)
    # @param default [Object] Default value when GraphQL response is nil
    # @param transform [Proc] Custom transform block for the value
    # @param raw_graphql [String] Raw GraphQL string to inject directly (escape hatch for unsupported features)
    def attribute(name, path: nil, type: :string, null: true, default: nil, transform: nil, raw_graphql: nil)
      path ||= infer_path(name)
      config = { path: path, type: type, null: null, default: default, transform: transform, raw_graphql: raw_graphql }

      if @current_loader_context
        # Store in loader-specific context
        @loader_contexts ||= {}
        @loader_contexts[@current_loader_context] ||= {}
        @loader_contexts[@current_loader_context][name] = config
      else
        # Store in base attributes, inheriting from parent if needed
        @base_attributes ||=
          if superclass.instance_variable_defined?(:@base_attributes)
            superclass.instance_variable_get(:@base_attributes).dup
          else
            {}
          end
        @base_attributes[name] = config
      end

      # Always create attr_accessor
      attr_accessor name unless method_defined?(name) || method_defined?("#{name}=")
    end

    # Get attributes for a specific loader class, merging base with loader-specific overrides.
    def attributes_for_loader(loader_class)
      base = @base_attributes || {}
      overrides = @loader_contexts&.dig(loader_class) || {}

      base.merge(overrides) { |_key, base_val, override_val| base_val.merge(override_val) }
    end

    private

    # Infer GraphQL path from Ruby attribute name (snake_case -> camelCase)
    def infer_path(name)
      name.to_s.gsub(/_([a-z])/) { ::Regexp.last_match(1).upcase }
    end
  end
end
