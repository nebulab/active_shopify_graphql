# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Configuration class for setting up external dependencies
  class Configuration
    attr_accessor :admin_api_executor, :customer_account_api_executor, :logger, :log_queries, :max_objects_per_paginated_query

    def initialize
      @admin_api_executor = nil
      @customer_account_api_executor = nil
      @logger = nil
      @log_queries = false
      @max_objects_per_paginated_query = 250
    end
  end
end
