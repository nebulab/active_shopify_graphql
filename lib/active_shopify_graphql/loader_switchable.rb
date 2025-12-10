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

    # Simple proxy class to handle loader delegation
    class LoaderProxy
      def initialize(model_class, loader, included_connections: [], selected_attributes: nil)
        @model_class = model_class
        @loader = loader
        @included_connections = included_connections
        @selected_attributes = selected_attributes
      end

      def includes(*connection_names)
        # Validate connections exist
        @model_class.send(:validate_includes_connections!, connection_names) if @model_class.respond_to?(:validate_includes_connections!, true)

        # Collect connections with eager_load: true
        auto_included_connections = @model_class.connections.select { |_name, config| config[:eager_load] }.keys

        # Merge manual and automatic connections
        all_included_connections = (@included_connections + connection_names + auto_included_connections).uniq

        # Create a new loader with the included connections
        new_loader = @loader.class.new(
          @model_class,
          *loader_extra_args,
          selected_attributes: @selected_attributes,
          included_connections: all_included_connections
        )

        LoaderProxy.new(
          @model_class,
          new_loader,
          included_connections: all_included_connections,
          selected_attributes: @selected_attributes
        )
      end

      def select(*attribute_names)
        new_selected = attribute_names.map(&:to_sym)

        # Create a new loader with the selected attributes
        new_loader = @loader.class.new(
          @model_class,
          *loader_extra_args,
          selected_attributes: new_selected,
          included_connections: @included_connections
        )

        LoaderProxy.new(
          @model_class,
          new_loader,
          included_connections: @included_connections,
          selected_attributes: new_selected
        )
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

      private

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
