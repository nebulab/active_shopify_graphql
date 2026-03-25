# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Configuration class for setting up external dependencies
  class Configuration
    attr_accessor :admin_api_executor, :customer_account_api_executor,
                  :admin_api_adapter, :customer_account_api_adapter,
                  :logger, :log_queries, :max_objects_per_paginated_query

    def initialize
      @admin_api_executor = nil
      @customer_account_api_executor = nil
      @admin_api_adapter = auto_detect_admin_adapter
      @customer_account_api_adapter = nil
      @logger = nil
      @log_queries = false
      @max_objects_per_paginated_query = 250
    end

    # Resolve the appropriate adapter for the given API type.
    # Prefers explicitly set adapters, falls back to wrapping executors.
    #
    # @param api_type [Symbol] Either :admin_api or :customer_account_api
    # @return [Adapters::Base, nil] The resolved adapter or nil if nothing configured
    def adapter_for(api_type)
      case api_type
      when :admin_api
        admin_api_adapter || wrap_executor(admin_api_executor)
      when :customer_account_api
        customer_account_api_adapter || wrap_executor(customer_account_api_executor)
      else
        raise ArgumentError, "Unknown API type: #{api_type}"
      end
    end

    private

    def auto_detect_admin_adapter
      return nil unless shopify_api_available?

      Adapters::ShopifyApiAdmin.new
    end

    def shopify_api_available?
      defined?(ShopifyAPI::Clients::Graphql::Admin)
    end

    def wrap_executor(executor)
      return nil unless executor

      Adapters::Proc.new(executor)
    end
  end
end
