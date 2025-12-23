# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Configuration class for setting up external dependencies
  class Configuration
    attr_accessor :admin_api_client, :customer_account_client_class, :logger, :log_queries, :max_objects_per_paginated_query

    def initialize
      @admin_api_client = nil
      @customer_account_client_class = nil
      @logger = nil
      @log_queries = false
      @max_objects_per_paginated_query = 250
    end
  end
end
