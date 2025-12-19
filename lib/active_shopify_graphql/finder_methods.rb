# frozen_string_literal: true

module ActiveShopifyGraphQL
  module FinderMethods
    extend ActiveSupport::Concern

    class_methods do
      # Find a single record by ID using the provided loader
      # @param id [String, Integer] The record ID (will be converted to GID automatically)
      # @param loader [ActiveShopifyGraphQL::Loader] The loader to use for fetching data
      # @return [Object] The model instance
      # @raise [ActiveShopifyGraphQL::ObjectNotFoundError] If the record is not found
      def find(id, loader: default_loader)
        gid = GidHelper.normalize_gid(id, model_name.name.demodulize)

        # If we have included connections, we need to handle inverse_of properly
        result =
          if loader.has_included_connections?
            loader.load_with_instance(gid, self)
          else
            attributes = loader.load_attributes(gid)
            attributes.nil? ? nil : new(attributes)
          end

        raise ObjectNotFoundError, "Couldn't find #{name} with id=#{id}" if result.nil?

        result
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

      # Find a single record by attribute conditions
      # @param conditions [Hash] The conditions to query (e.g., { email: "example@test.com", first_name: "John" })
      # @param options [Hash] Options hash containing loader
      # @option options [ActiveShopifyGraphQL::Loader] :loader The loader to use for fetching data
      # @return [Object, nil] The first matching model instance or nil if not found
      # @raise [ArgumentError] If any attribute is not valid for querying
      #
      # @example
      #   # Keyword argument style (recommended)
      #   Customer.find_by(email: "john@example.com")
      #   Customer.find_by(first_name: "John", country: "Canada")
      #   Customer.find_by(orders_count: { gte: 5 })
      #
      #   # Hash style with options
      #   Customer.find_by({ email: "john@example.com" }, loader: custom_loader)
      def find_by(conditions_or_first_condition = {}, *args, **options)
        where(conditions_or_first_condition, *args, **options).first
      end

      # Query for multiple records using attribute conditions
      # Returns a QueryScope that supports chaining .limit() and .in_pages()
      #
      # Supports two query styles:
      # 1. Hash-based (safe, with automatic sanitization) - burden on library
      # 2. String-based (raw query, no sanitization) - burden on developer
      #
      # @param conditions_or_first_condition [Hash, String] The conditions to query
      # @param options [Hash] Options hash containing loader (when first arg is a Hash)
      # @option options [ActiveShopifyGraphQL::Loader] :loader The loader to use for fetching data
      # @return [QueryScope] A chainable query scope
      # @raise [ArgumentError] If any attribute is not valid for querying
      #
      # @example Hash-based query (safe, escaped)
      #   Customer.where(email: "john@example.com").to_a
      #   # => produces: query:"email:'john@example.com'"
      #
      # @example String-based query (raw, allows wildcards)
      #   ProductVariant.where("sku:*").to_a
      #   # => produces: query:"sku:*" (wildcard matching enabled)
      #
      # @example With limit
      #   Customer.where(first_name: "John").limit(100).to_a
      #
      # @example With pagination block
      #   Customer.where(orders_count: { gte: 5 }).in_pages(of: 50) do |page|
      #     page.each { |customer| process(customer) }
      #   end
      #
      # @example Manual pagination
      #   page = Customer.where(email: "*@example.com").in_pages(of: 25)
      #   page.has_next_page? # => true
      #   next_page = page.next_page
      def where(conditions_or_first_condition = {}, *args, **options)
        # Handle string-based queries (raw query syntax)
        if conditions_or_first_condition.is_a?(String)
          loader = options[:loader] || default_loader
          loader.instance_variable_set(:@model_class, self) if loader.instance_variable_get(:@model_class).nil?
          return QueryScope.new(self, conditions: conditions_or_first_condition, loader: loader)
        end

        # Handle hash-based queries (with sanitization)
        # where(email: "john@example.com") - keyword args become options
        # where({ email: "john@example.com" }, loader: custom_loader) - explicit hash + options
        if conditions_or_first_condition.is_a?(Hash) && !conditions_or_first_condition.empty?
          # Explicit hash provided as first argument
          conditions = conditions_or_first_condition
          # Any additional options passed as keyword args or second hash argument
          final_options = args.first.is_a?(Hash) ? options.merge(args.first) : options
        else
          # Keyword arguments style - conditions come from options, excluding known option keys
          known_option_keys = %i[loader]
          conditions = options.except(*known_option_keys)
          final_options = options.slice(*known_option_keys)
        end

        loader = final_options[:loader] || default_loader

        # Ensure loader has model class set - needed for graphql_type inference
        loader.instance_variable_set(:@model_class, self) if loader.instance_variable_get(:@model_class).nil?

        QueryScope.new(self, conditions: conditions, loader: loader)
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
