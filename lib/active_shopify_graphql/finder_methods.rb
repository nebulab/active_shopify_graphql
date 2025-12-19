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
      # @param conditions [Hash] The conditions to query
      # @return [Object, nil] The first matching model instance or nil if not found
      #
      # @example
      #   Customer.find_by(email: "john@example.com")
      #   Customer.find_by(first_name: "John", country: "Canada")
      #   Customer.find_by(orders_count: { gte: 5 })
      def find_by(conditions = {}, **options)
        where(conditions.empty? ? options : conditions).first
      end

      # Query for multiple records using attribute conditions
      # Returns a QueryScope that supports chaining .limit() and .in_pages()
      #
      # Supports three query styles:
      # 1. Hash-based (safe, with automatic sanitization) - burden on library
      # 2. String-based (raw query, no sanitization) - burden on developer
      # 3. String with parameter binding (safe, with sanitization) - burden on library
      #
      # @param conditions_or_first_condition [Hash, String] The conditions to query
      # @param args [Array] Additional positional arguments for parameter binding
      # @param options [Hash] Named parameters for parameter binding
      # @return [QueryScope] A chainable query scope
      #
      # @example Hash-based query (safe, escaped)
      #   Customer.where(email: "john@example.com").to_a
      #   # => produces: query:"email:'john@example.com'"
      #
      # @example String-based query (raw, allows wildcards)
      #   ProductVariant.where("sku:*").to_a
      #   # => produces: query:"sku:*" (wildcard matching enabled)
      #
      # @example String with positional parameter binding (safe)
      #   ProductVariant.where("sku:? product_id:?", "Good ol' value", 123).to_a
      #   # => produces: query:"sku:'Good ol\\' value' product_id:123"
      #
      # @example String with named parameter binding (safe)
      #   ProductVariant.where("sku::sku product_id::id", { sku: "A-SKU", id: 123 }).to_a
      #   ProductVariant.where("sku::sku", sku: "A-SKU").to_a
      #   # => produces: query:"sku:'A-SKU' product_id:123"
      #
      # @example With limit
      #   Customer.where(first_name: "John").limit(100).to_a
      #
      # @example With pagination block
      #   Customer.where(orders_count: { gte: 5 }).in_pages(of: 50) do |page|
      #     page.each { |customer| process(customer) }
      #   end
      def where(conditions_or_first_condition = {}, *args, **options)
        # Handle string-based queries (raw query syntax or with parameter binding)
        if conditions_or_first_condition.is_a?(String)
          # Named parameters can come from keyword args: where("sku::sku", sku: "foo")
          # Positional parameters come from positional args: where("sku:?", "foo")
          binding_params = args.empty? && options.any? ? [options] : args

          conditions = binding_params.empty? ? conditions_or_first_condition : [conditions_or_first_condition, *binding_params]
          return QueryScope.new(self, conditions: conditions)
        end

        # Handle hash-based queries (with sanitization)
        # where(email: "john@example.com") - keyword args become options
        # where({ email: "john@example.com" }) - explicit hash
        conditions = if conditions_or_first_condition.is_a?(Hash) && !conditions_or_first_condition.empty?
                       conditions_or_first_condition
                     else
                       options
                     end

        QueryScope.new(self, conditions: conditions)
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
