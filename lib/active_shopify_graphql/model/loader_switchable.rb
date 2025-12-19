# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Model
    # Provides capability to switch between different loaders within the same model
    module LoaderSwitchable
      extend ActiveSupport::Concern

      # Generic method to execute with a specific loader
      # @param loader_class [Class] The loader class to use
      # @yield [Object] Block to execute with the loader
      # @return [Object] Result of the block
      def with_loader(loader_class, &_block)
        old_loader = Thread.current[:active_shopify_graphql_loader]
        Thread.current[:active_shopify_graphql_loader] = loader_class.new(self.class)

        if block_given?
          yield(self)
        else
          self
        end
      ensure
        Thread.current[:active_shopify_graphql_loader] = old_loader
      end

      # Executes with the admin API loader
      # @return [self]
      def with_admin_api(&block)
        with_loader(ActiveShopifyGraphQL::Loaders::AdminApiLoader, &block)
      end

      # Executes with the customer account API loader
      # @return [self]
      def with_customer_account_api(&block)
        with_loader(ActiveShopifyGraphQL::Loaders::CustomerAccountApiLoader, &block)
      end

      class_methods do
        # @!method use_loader(loader_class)
        #   Sets the default loader class for this model.
        #
        #   @param loader_class [Class] The loader class to use as default
        #   @example
        #     class Customer < ActiveRecord::Base
        #       use_loader ActiveShopifyGraphQL::Loaders::CustomerAccountApiLoader
        #     end
        def use_loader(loader_class)
          @default_loader_class = loader_class
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

        # Class-level method to execute with admin API loader
        # @return [LoaderProxy] Proxy object with find method
        def with_admin_api
          LoaderProxy.new(self, ActiveShopifyGraphQL::Loaders::AdminApiLoader.new(self))
        end

        # Class-level method to execute with customer account API loader
        # @return [LoaderProxy] Proxy object with find method
        def with_customer_account_api(token = nil)
          LoaderProxy.new(self, ActiveShopifyGraphQL::Loaders::CustomerAccountApiLoader.new(self, token))
        end

        private

        # Returns the default loader class (either set via DSL or inferred)
        # @return [Class] The default loader class
        def default_loader_class
          @default_loader_class ||= ActiveShopifyGraphQL::Loaders::AdminApiLoader
        end
      end

      # Simple proxy class to handle loader delegation when using a specific API
      # This provides a consistent interface with Relation while using a custom loader
      class LoaderProxy
        def initialize(model_class, loader)
          @model_class = model_class
          @loader = loader
        end

        # Create a Relation with this loader's configuration
        # @return [Relation] A relation configured with this loader
        def all
          build_relation
        end

        # Delegate chainable methods to Relation
        def includes(*connection_names)
          build_relation.includes(*connection_names)
        end

        def select(*attribute_names)
          build_relation.select(*attribute_names)
        end

        def where(*args, **options)
          build_relation.where(*args, **options)
        end

        def find_by(conditions = {}, **options)
          build_relation.find_by(conditions, **options)
        end

        def find(id = nil)
          # For Customer Account API, if no ID is provided, load the current customer
          if id.nil? && @loader.is_a?(ActiveShopifyGraphQL::Loaders::CustomerAccountApiLoader)
            attributes = @loader.load_attributes
            return nil if attributes.nil?

            return @model_class.new(attributes)
          end

          # For other cases, require ID and use standard flow
          return nil if id.nil?

          build_relation.find(id)
        end

        attr_reader :loader

        def inspect
          "#{@model_class.name}(with_#{@loader.class.name.demodulize})"
        end
        alias to_s inspect

        private

        def build_relation
          Query::Relation.new(
            @model_class,
            loader_class: @loader.class,
            loader_extra_args: loader_extra_args
          )
        end

        # Returns extra arguments needed when creating a new loader of the same type
        # For CustomerAccountApiLoader, this includes the token
        def loader_extra_args
          if @loader.is_a?(ActiveShopifyGraphQL::Loaders::CustomerAccountApiLoader)
            [@loader.instance_variable_get(:@token)]
          else
            []
          end
        end
      end
    end
  end
end
