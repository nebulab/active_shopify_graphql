# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Helper module for handling Shopify Global IDs (GIDs)
  # Provides utilities for parsing and building GIDs according to the URI::GID standard
  module GidHelper
    # Normalize an ID value to a proper Shopify GID format
    # If the ID is already a valid GID, returns it as-is
    # Otherwise, builds a new GID using the provided model name
    #
    # @param id [String, Integer] The ID value (can be numeric or existing GID)
    # @param model_name [String] The GraphQL type name (e.g., "Customer", "Order")
    # @return [String] The normalized GID in format "gid://shopify/ModelName/id"
    #
    # @example
    #   normalize_gid(123, "Customer")
    #   # => "gid://shopify/Customer/123"
    #
    #   normalize_gid("gid://shopify/Customer/123", "Customer")
    #   # => "gid://shopify/Customer/123"
    #
    def self.normalize_gid(id, model_name)
      # Check if id is already a valid GID
      begin
        parsed_gid = URI::GID.parse(id)
        return id if parsed_gid
      rescue URI::InvalidURIError, URI::BadURIError, ArgumentError
        # Not a valid GID, proceed to build one
      end

      # Build GID from the provided ID and model name
      URI::GID.build(app: "shopify", model_name: model_name, model_id: id).to_s
    end

    # Check if a value is a valid Shopify GID
    #
    # @param value [String] The value to check
    # @return [Boolean] true if the value is a valid GID, false otherwise
    #
    # @example
    #   valid_gid?("gid://shopify/Customer/123")
    #   # => true
    #
    #   valid_gid?("123")
    #   # => false
    #
    def self.valid_gid?(value)
      URI::GID.parse(value)
      true
    rescue URI::InvalidURIError, URI::BadURIError, ArgumentError
      false
    end
  end
end
