# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Configuration class for setting up external dependencies
  class Configuration
    attr_accessor :admin_api_executor, :customer_account_api_executor, :logger, :log_queries,
                  :max_objects_per_paginated_query, :test_mode

    def initialize
      @admin_api_executor = nil
      @customer_account_api_executor = nil
      @logger = nil
      @log_queries = false
      @max_objects_per_paginated_query = 250
      @test_mode = false
    end

    # Check if test mode is enabled
    # @return [Boolean]
    def test_mode?
      @test_mode
    end
  end
end
