module ActiveShopifyGraphQL
  module LoaderSwitchable
    extend ActiveSupport::Concern

    class_methods do
      # DSL method to set the default loader class
      # @param loader_class [Class] The loader class to use as default
      def uses_loader(loader_class)
        @default_loader_class = loader_class
      end

      # Returns an instance of the default loader
      # @return [Shopify::Loader] The default loader instance
      def default_loader_instance
        @default_loader_instance ||= default_loader_class.new
      end

      # Returns the default loader class (either set via DSL or inferred)
      # @return [Class] The default loader class
      def default_loader_class
        @default_loader_class ||= infer_loader_class('AdminApi')
      end

      # Use Admin API loader - returns a finder proxy that uses the admin API
      # @return [Object] An object with find method using Admin API
      def with_admin_api
        LoaderProxy.new(self, admin_api_loader_class.new)
      end

      # Use Customer Account API loader with provided token
      # @param token [String] The customer access token
      # @return [Object] An object with find method using Customer Account API
      def with_customer_account_api(token)
        LoaderProxy.new(self, customer_account_api_loader_class.new(token))
      end

      # Override this method to customize the Admin API loader class
      # @return [Class] The Admin API loader class
      def admin_api_loader_class
        @admin_api_loader_class ||= infer_loader_class('AdminApi')
      end

      # Override this method to customize the Customer Account API loader class
      # @return [Class] The Customer Account API loader class
      def customer_account_api_loader_class
        @customer_account_api_loader_class ||= infer_loader_class('CustomerAccountApi')
      end

      # Allows setting a custom Admin API loader class
      # @param klass [Class] The loader class to use for Admin API
      def admin_api_loader_class=(klass)
        @admin_api_loader_class = klass
      end

      # Allows setting a custom Customer Account API loader class
      # @param klass [Class] The loader class to use for Customer Account API
      def customer_account_api_loader_class=(klass)
        @customer_account_api_loader_class = klass
      end

      private

      # Infers loader class from model name using naming conventions
      # e.g., Shopify::Customer + 'AdminApi' -> ActiveShopifyGraphQL::Loaders::AdminApi::CustomerLoader
      # @param api_type [String] The API type ('AdminApi' or 'CustomerAccountApi')
      # @return [Class] The inferred loader class
      def infer_loader_class(api_type)
        model_name = name.demodulize # e.g., 'Customer' from 'Shopify::Customer'

        loader_class_name = "ActiveShopifyGraphQL::Loaders::#{api_type}::#{model_name}Loader"
        loader_class_name.constantize
      rescue NameError => e
        raise NameError, "Could not find loader class '#{loader_class_name}' for model '#{name}'. " \
                        "Please create the loader class or override the #{api_type.underscore}_loader_class method. " \
                        "Original error: #{e.message}"
      end

      # Simple proxy class to handle loader delegation
      class LoaderProxy
        def initialize(model_class, loader)
          @model_class = model_class
          @loader = loader
        end

        def find(id = nil)
          model_type = @model_class.name.demodulize

          # Convert to GID only if ID is provided
          gid = id ? @model_class.send(:convert_to_gid, id) : nil
          attributes = @loader.load_attributes(gid, model_type)

          return nil if attributes.nil?

          @model_class.new(attributes)
        end

        def loader
          @loader
        end

        def inspect
          "#{@model_class.name}(with_#{@loader.class.name.demodulize})"
        end
        alias_method :to_s, :inspect
      end
    end
  end
end
