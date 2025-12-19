# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Model
    # Centralizes GraphQL type resolution logic.
    module GraphqlTypeResolver
      extend ActiveSupport::Concern

      class_methods do
        # Set or get the base GraphQL type for this model.
        #
        # @param type [String, nil] The GraphQL type name to set, or nil to get
        # @return [String] The GraphQL type name
        # @raise [NotImplementedError] If no type is defined
        def graphql_type(type = nil)
          if type
            if @current_loader_context
              @loader_graphql_types ||= {}
              @loader_graphql_types[@current_loader_context] = type
            else
              @base_graphql_type = type
            end
          end

          @base_graphql_type || raise(NotImplementedError, "#{self} must define graphql_type")
        end

        # Get the GraphQL type for a specific loader class.
        # Resolution order:
        #   1. Loader-specific type defined via `for_loader`
        #   2. Base graphql_type defined on the model
        #   3. Type defined on the loader class itself
        #   4. Inferred from model class name
        #
        # @param loader_class [Class] The loader class to resolve type for
        # @return [String] The resolved GraphQL type
        # @raise [NotImplementedError] If no type can be resolved
        def graphql_type_for_loader(loader_class)
          # 1. Check loader-specific override
          return @loader_graphql_types[loader_class] if @loader_graphql_types&.key?(loader_class)

          # 2. Check base graphql_type
          return @base_graphql_type if @base_graphql_type

          # 3. Check loader class itself
          loader_type = loader_class.instance_variable_get(:@graphql_type)
          return loader_type if loader_type

          # 4. Infer from model name
          return name.demodulize if respond_to?(:name) && name

          raise NotImplementedError,
                "#{self} must define graphql_type or #{loader_class} must define graphql_type"
        end

        # Resolve the GraphQL type from any source (model class, loader, or value).
        # Useful for external callers that need to resolve type from various inputs.
        #
        # @param model_class [Class, nil] The model class
        # @param loader_class [Class, nil] The loader class
        # @return [String] The resolved GraphQL type
        def resolve_graphql_type(model_class: nil, loader_class: nil)
          if model_class.respond_to?(:graphql_type_for_loader) && loader_class
            model_class.graphql_type_for_loader(loader_class)
          elsif model_class.respond_to?(:graphql_type)
            model_class.graphql_type
          elsif loader_class.respond_to?(:graphql_type)
            loader_class.graphql_type
          elsif model_class.respond_to?(:name) && model_class.name
            model_class.name.demodulize
          else
            raise ArgumentError, "Cannot resolve graphql_type from provided arguments"
          end
        end
      end

      # Module-level resolver for convenience
      def self.resolve(model_class: nil, loader_class: nil)
        if model_class.respond_to?(:graphql_type_for_loader) && loader_class
          model_class.graphql_type_for_loader(loader_class)
        elsif model_class.respond_to?(:graphql_type)
          model_class.graphql_type
        elsif loader_class.respond_to?(:graphql_type)
          loader_class.graphql_type
        elsif model_class.respond_to?(:name) && model_class.name
          model_class.name.demodulize
        else
          raise ArgumentError, "Cannot resolve graphql_type"
        end
      end
    end
  end
end
