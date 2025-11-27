module ActiveShopifyGraphQL
  module FinderMethods
    extend ActiveSupport::Concern

    class_methods do
      # Find a single record by ID using the provided loader
      # @param id [String, Integer] The record ID (will be converted to GID automatically)
      # @param loader [ActiveShopifyGraphQL::Loader] The loader to use for fetching data
      # @return [Object, nil] The model instance or nil if not found
      def find(id, loader: default_loader)
        gid = URI::GID.build(app: "shopify", model_name: model_name.name.demodulize, id: id)
        model_type = name.demodulize
        attributes = loader.load_attributes(gid, model_type)

        return nil if attributes.nil?

        new(attributes)
      end

      # Returns the default loader for this model's queries
      # @return [Shopify::Loader] The default loader instance
      def default_loader
        if respond_to?(:default_loader_instance)
          default_loader_instance
        else
          @default_loader ||= default_loader_class.new
        end
      end

      # Allows setting a custom default loader (useful for testing)
      # @param loader [Shopify::Loader] The loader to set as default
      def default_loader=(loader)
        @default_loader = loader
      end

      private

      # Infers the loader class name from the model name
      # e.g., Shopify::Customer -> Shopify::CustomerLoader
      # @return [Class] The loader class
      def default_loader_class
        loader_class_name = "#{name}Loader"
        loader_class_name.constantize
      rescue NameError => e
        raise NameError, "Default loader class '#{loader_class_name}' not found for model '#{name}'. " \
                        "Please create the loader class or override the default_loader method. " \
                        "Original error: #{e.message}"
      end
    end
  end
end
