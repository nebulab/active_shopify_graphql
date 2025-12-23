# frozen_string_literal: true

module ActiveShopifyGraphQL::Model::LoaderSwitchable
  # Provides capability to switch between different loaders within the same model
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
      ActiveShopifyGraphQL::LoaderProxy.new(self, ActiveShopifyGraphQL::Loaders::AdminApiLoader.new(self))
    end

    # Class-level method to execute with customer account API loader
    # @return [LoaderProxy] Proxy object with find method
    def with_customer_account_api(token = nil)
      ActiveShopifyGraphQL::LoaderProxy.new(self, ActiveShopifyGraphQL::Loaders::CustomerAccountApiLoader.new(self, token))
    end

    private

    # Returns the default loader class (either set via DSL or inferred)
    # @return [Class] The default loader class
    def default_loader_class
      @default_loader_class ||= ActiveShopifyGraphQL::Loaders::AdminApiLoader
    end
  end
end
