# frozen_string_literal: true

module ActiveShopifyGraphQL
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
      with_loader(ActiveShopifyGraphQL::AdminApiLoader, &block)
    end

    # Executes with the customer account API loader
    # @return [self]
    def with_customer_account_api(&block)
      with_loader(ActiveShopifyGraphQL::CustomerAccountApiLoader, &block)
    end

    class_methods do
      # @!method use_loader(loader_class)
      #   Sets the default loader class for this model.
      #
      #   @param loader_class [Class] The loader class to use as default
      #   @example
      #     class Customer < ActiveRecord::Base
      #       use_loader ActiveShopifyGraphQL::CustomerAccountApiLoader
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
        LoaderProxy.new(self, ActiveShopifyGraphQL::AdminApiLoader.new(self))
      end

      # Class-level method to execute with customer account API loader
      # @return [LoaderProxy] Proxy object with find method
      def with_customer_account_api(token = nil)
        LoaderProxy.new(self, ActiveShopifyGraphQL::CustomerAccountApiLoader.new(self, token))
      end

      private

      # Returns the default loader class (either set via DSL or inferred)
      # @return [Class] The default loader class
      def default_loader_class
        @default_loader_class ||= ActiveShopifyGraphQL::AdminApiLoader
      end
    end

    # Simple proxy class to handle loader delegation
    class LoaderProxy
      def initialize(model_class, loader)
        @model_class = model_class
        @loader = loader
      end

      def find(id = nil)
        # For Customer Account API, if no ID is provided, load the current customer
        if id.nil? && @loader.is_a?(ActiveShopifyGraphQL::CustomerAccountApiLoader)
          attributes = @loader.load_attributes
          return nil if attributes.nil?

          return @model_class.new(attributes)
        end

        # For other cases, require ID and use standard flow
        return nil if id.nil?

        gid = GidHelper.normalize_gid(id, @model_class.model_name.name.demodulize)

        attributes = @loader.load_attributes(gid)
        return nil if attributes.nil?

        @model_class.new(attributes)
      end

      # Delegate where to the model class with the specific loader
      def where(*args, **options)
        @model_class.where(*args, **options.merge(loader: @loader))
      end

      attr_reader :loader

      def inspect
        "#{@model_class.name}(with_#{@loader.class.name.demodulize})"
      end
      alias to_s inspect
    end
  end
end
