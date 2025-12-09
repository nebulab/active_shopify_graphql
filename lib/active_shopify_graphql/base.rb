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
      include ActiveShopifyGraphQL::Attributes
      include ActiveShopifyGraphQL::MetafieldAttributes
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
        @loader_graphql_types&.dig(loader_class) ||
          @base_graphql_type ||
          loader_class.instance_variable_get(:@graphql_type) ||
          (respond_to?(:name) && name ? name.demodulize : nil) ||
          raise(NotImplementedError, "#{self} must define graphql_type or #{loader_class} must define graphql_type")
      end

      private

      # Override graphql_type method to handle loader context
      def graphql_type_with_context(type = nil, for_loader: nil)
        if type && @current_loader_context
          @loader_graphql_types ||= {}
          @loader_graphql_types[@current_loader_context] = type
        else
          graphql_type_without_context(type, for_loader: for_loader)
        end
      end

      # Alias methods to support context handling
      alias_method :graphql_type_without_context, :graphql_type
      alias_method :graphql_type, :graphql_type_with_context
    end

    def initialize(attributes = {})
      super()

      # Extract connection cache if present
      @_connection_cache = attributes.delete(:_connection_cache) if attributes.key?(:_connection_cache)

      assign_attributes(attributes)
    end
  end
end
