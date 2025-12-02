# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Base
    extend ActiveSupport::Concern

    included do
      include ActiveModel::AttributeAssignment
      include ActiveModel::Validations
      extend ActiveModel::Naming
      include ActiveShopifyGraphQL::FinderMethods
      include ActiveShopifyGraphQL::Associations
      include ActiveShopifyGraphQL::Connections
      include ActiveShopifyGraphQL::LoaderSwitchable
    end

    class_methods do
      # Set or get the GraphQL type for this model
      def graphql_type(type = nil, for_loader: nil)
        if type
          if for_loader
            @loader_graphql_types ||= {}
            @loader_graphql_types[for_loader] = type
          else
            @base_graphql_type = type
          end
        end

        @base_graphql_type || raise(NotImplementedError, "#{self} must define graphql_type")
      end

      # Get GraphQL type for a specific loader
      def graphql_type_for_loader(loader_class)
        @loader_graphql_types&.dig(loader_class) || @base_graphql_type || loader_class.instance_variable_get(:@graphql_type) || raise(NotImplementedError, "#{self} must define graphql_type or #{loader_class} must define graphql_type")
      end

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

      # Define loader-specific attribute and graphql_type overrides
      # @param loader_class [Class] The loader class to override attributes for
      def for_loader(loader_class, &block)
        @current_loader_context = loader_class
        @loader_contexts ||= {}
        @loader_contexts[loader_class] ||= {}
        instance_eval(&block) if block_given?
        @current_loader_context = nil
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

      # Get metafields defined for this model
      def metafields
        @metafields || {}
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

      # Override graphql_type method to handle loader context
      def graphql_type_with_context(type = nil, for_loader: nil)
        if type && @current_loader_context
          @loader_graphql_types ||= {}
          @loader_graphql_types[@current_loader_context] = type
        else
          graphql_type_without_context(type, for_loader: for_loader)
        end
      end

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
      alias_method :attribute_without_context, :attribute
      alias_method :attribute, :attribute_with_context

      alias_method :metafield_attribute_without_context, :metafield_attribute
      alias_method :metafield_attribute, :metafield_attribute_with_context

      alias_method :graphql_type_without_context, :graphql_type
      alias_method :graphql_type, :graphql_type_with_context

      # Infer GraphQL path from Ruby attribute name
      # Only handles simple snake_case to camelCase conversion
      def infer_path(name)
        name.to_s.gsub(/_([a-z])/) { ::Regexp.last_match(1).upcase }
      end
    end

    def initialize(attributes = {})
      super()
      assign_attributes(attributes)
    end
  end
end
