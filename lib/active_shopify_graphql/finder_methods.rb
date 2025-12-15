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
        gid = GidHelper.normalize_gid(id, model_name.name.demodulize)

        # If we have included connections, we need to handle inverse_of properly
        if loader.respond_to?(:load_with_instance) && loader.has_included_connections?
          loader.load_with_instance(gid, self)
        else
          attributes = loader.load_attributes(gid)
          return nil if attributes.nil?

          new(attributes)
        end
      end

      # Returns the default loader for this model's queries
      # @return [ActiveGraphQL::Loader] The default loader instance
      def default_loader
        if respond_to?(:default_loader_instance)
          default_loader_instance
        else
          @default_loader ||= begin
            # Collect connections with eager_load: true
            eagerly_loaded_connections = connections.select { |_name, config| config[:eager_load] }.keys

            default_loader_class.new(
              self,
              included_connections: eagerly_loaded_connections
            )
          end
        end
      end

      # Allows setting a custom default loader (useful for testing)
      # @param loader [ActiveGraphQL::Loader] The loader to set as default
      def default_loader=(loader)
        @default_loader = loader
      end

      # Select specific attributes to optimize GraphQL queries
      # @param *attributes [Symbol] The attributes to select
      # @return [Class] A class with modified default loader for method chaining
      #
      # @example
      #   Customer.select(:id, :email).find(123)
      #   Customer.select(:id, :email).where(first_name: "John")
      def select(*attributes)
        # Validate attributes exist
        attrs = Array(attributes).flatten.map(&:to_sym)
        validate_select_attributes!(attrs)

        # Create a new class that inherits from self with a modified default loader
        selected_class = Class.new(self)

        # Override the default_loader method to return a loader with selected attributes
        selected_class.define_singleton_method(:default_loader) do
          @default_loader ||= superclass.default_loader.class.new(
            superclass,
            selected_attributes: attrs
          )
        end

        # Preserve the original class name and model name for GraphQL operations
        selected_class.define_singleton_method(:name) { superclass.name }
        selected_class.define_singleton_method(:model_name) { superclass.model_name }

        selected_class
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

        # Ensure loader has model class set - needed for graphql_type inference
        loader.instance_variable_set(:@model_class, self) if loader.instance_variable_get(:@model_class).nil?

        attributes_array = loader.load_collection(conditions, limit: limit)

        attributes_array.map { |attributes| new(attributes) }
      end

      private

      # Validates that selected attributes exist in the model
      # @param attributes [Array<Symbol>] The attributes to validate
      # @raise [ArgumentError] If any attribute is invalid
      def validate_select_attributes!(attributes)
        return if attributes.empty?

        available_attrs = available_select_attributes
        invalid_attrs = attributes - available_attrs

        return unless invalid_attrs.any?

        raise ArgumentError, "Invalid attributes for #{name}: #{invalid_attrs.join(', ')}. " \
                           "Available attributes are: #{available_attrs.join(', ')}"
      end

      # Gets all available attributes for selection
      # @return [Array<Symbol>] Available attribute names
      def available_select_attributes
        attrs = []

        # Get attributes from the model class
        loader_class = default_loader.class
        model_attrs = attributes_for_loader(loader_class)
        attrs.concat(model_attrs.keys)

        # Get attributes from the loader class
        loader_attrs = default_loader.class.defined_attributes
        attrs.concat(loader_attrs.keys)

        attrs.map(&:to_sym).uniq.sort
      end
    end
  end
end
