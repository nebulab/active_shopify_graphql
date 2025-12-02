# frozen_string_literal: true

module ActiveShopifyGraphQL
  module FinderMethods
    extend ActiveSupport::Concern

    class_methods do
      # Find a single record by ID using the provided loader
      # @param id [String, Integer] The record ID (will be converted to GID automatically)
      # @param loader [ActiveShopifyGraphQL::Loader] The loader to use for fetching data
      # @return [Object, nil] The model instance or nil if not found
      def find(id, loader: default_loader)
        gid = URI::GID.build(app: "shopify", model_name: model_name.name.demodulize, model_id: id)
        model_type = name.demodulize
        attributes = loader.load_attributes(model_type, gid)

        return nil if attributes.nil?

        new(attributes)
      end

      # Returns the default loader for this model's queries
      # @return [ActiveGraphQL::Loader] The default loader instance
      def default_loader
        if respond_to?(:default_loader_instance)
          default_loader_instance
        else
          @default_loader ||= default_loader_class.new
        end
      end

      # Allows setting a custom default loader (useful for testing)
      # @param loader [ActiveGraphQL::Loader] The loader to set as default
      def default_loader=(loader)
        @default_loader = loader
      end

      # Query for multiple records using attribute conditions
      # @param conditions [Hash] The conditions to query (e.g., { email: "example@test.com", first_name: "John" })
      # @param options [Hash] Options hash containing loader and limit (when first arg is a Hash)
      # @option options [ActiveShopifyGraphQL::Loader] :loader The loader to use for fetching data
      # @option options [Integer] :limit The maximum number of records to return (default: 250, max: 250)
      # @return [Array<Object>] Array of model instances
      # @raise [ArgumentError] If any attribute is not valid for querying
      #
      # @example
      #   # Keyword argument style (recommended)
      #   Customer.where(email: "john@example.com")
      #   Customer.where(first_name: "John", country: "Canada")
      #   Customer.where(orders_count: { gte: 5 })
      #   Customer.where(created_at: { gte: "2024-01-01", lt: "2024-02-01" })
      #
      #   # Hash style with options
      #   Customer.where({ email: "john@example.com" }, loader: custom_loader, limit: 100)
      def where(conditions_or_first_condition = {}, *args, **options)
        # Handle both syntaxes:
        # where(email: "john@example.com") - keyword args become options
        # where({ email: "john@example.com" }, loader: custom_loader) - explicit hash + options
        if conditions_or_first_condition.is_a?(Hash) && !conditions_or_first_condition.empty?
          # Explicit hash provided as first argument
          conditions = conditions_or_first_condition
          # Any additional options passed as keyword args or second hash argument
          final_options = args.first.is_a?(Hash) ? options.merge(args.first) : options
        else
          # Keyword arguments style - conditions come from options, excluding known option keys
          known_option_keys = %i[loader limit]
          conditions = options.except(*known_option_keys)
          final_options = options.slice(*known_option_keys)
        end

        loader = final_options[:loader] || default_loader
        limit = final_options[:limit] || 250

        model_type = name.demodulize
        attributes_array = loader.load_collection(model_type, conditions, limit: limit)

        attributes_array.map { |attributes| new(attributes) }
      end

      private

      # Infers the loader class name from the model name
      # e.g., Customer -> ActiveGraphQL::CustomerLoader
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
