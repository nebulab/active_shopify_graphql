# frozen_string_literal: true

module ActiveShopifyGraphQL::Model::FinderMethods
  extend ActiveSupport::Concern

  class_methods do
    # Returns a Relation for the model that can be chained
    # @return [Relation] A new relation for this model
    def all
      ActiveShopifyGraphQL::Query::Relation.new(self)
    end

    # Find a single record by ID
    # For Customer Account API, if no ID is provided, fetches the current customer
    # @param id [String, Integer, nil] The record ID (will be converted to GID automatically)
    # @param loader [ActiveShopifyGraphQL::Loader] The loader to use for fetching data (deprecated, use Relation chain)
    # @return [Object] The model instance
    # @raise [ActiveShopifyGraphQL::ObjectNotFoundError] If the record is not found
    # @raise [ArgumentError] If id is nil and not using Customer Account API loader
    def find(id = nil)
      all.find(id)
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

    # Find a single record by attribute conditions
    # @param conditions [Hash] The conditions to query
    # @return [Object, nil] The first matching model instance or nil if not found
    #
    # @example
    #   Customer.find_by(email: "john@example.com")
    #   Customer.find_by(first_name: "John", country: "Canada")
    #   Customer.find_by(orders_count: { gte: 5 })
    def find_by(conditions = {}, **options)
      all.find_by(conditions.empty? ? options : conditions)
    end

    # Query for multiple records using attribute conditions
    # Returns a Relation that supports chaining .limit(), .includes(), .find_by() and .in_pages()
    #
    # Supports three query styles:
    # 1. Hash-based (safe, with automatic sanitization) - burden on library
    # 2. String-based (raw query, no sanitization) - burden on developer
    # 3. String with parameter binding (safe, with sanitization) - burden on library
    #
    # @param conditions_or_first_condition [Hash, String] The conditions to query
    # @param args [Array] Additional positional arguments for parameter binding
    # @param options [Hash] Named parameters for parameter binding
    # @return [Relation] A chainable relation
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
      all.where(conditions_or_first_condition, *args, **options)
    end

    # Select specific attributes to optimize GraphQL queries
    # @param attributes [Symbol] The attributes to select
    # @return [Relation] A relation with selected attributes
    #
    # @example
    #   Customer.select(:id, :email).find(123)
    #   Customer.select(:id, :email).where(first_name: "John")
    def select(*attributes)
      all.select(*attributes)
    end

    # Include connections for eager loading
    # @param connection_names [Array<Symbol>] Connection names to include
    # @return [Relation] A relation with connections included
    #
    # @example
    #   Customer.includes(:orders).find(123)
    #   Customer.includes(:orders, :addresses).where(country: "Canada")
    def includes(*connection_names)
      all.includes(*connection_names)
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
