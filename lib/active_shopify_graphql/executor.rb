# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Handles GraphQL query execution for different client types
  class Executor
    attr_reader :client_type

    def initialize(client_type)
      @client_type = client_type
    end

    # Executes a GraphQL query with optional logging
    # @param query [String] The GraphQL query string
    # @param variables [Hash] The query variables
    # @return [Hash] The GraphQL response data
    def execute(query, **variables)
      log_query(query, variables) if should_log?
      perform_query(query, **variables)
    end

    private

    # Determines if queries should be logged based on configuration
    def should_log?
      ActiveShopifyGraphQL.configuration.log_queries && ActiveShopifyGraphQL.configuration.logger
    end

    # Logs the query and variables
    def log_query(query, variables)
      logger = ActiveShopifyGraphQL.configuration.logger
      logger.info("ActiveShopifyGraphQL Query:\n#{query}")
      logger.info("ActiveShopifyGraphQL Variables:\n#{variables}")
    end

    # Performs the actual GraphQL query execution based on client type
    # @param query [String] The GraphQL query string
    # @param variables [Hash] The query variables
    # @return [Hash] The GraphQL response data
    def perform_query(query, **variables)
      case @client_type
      when :admin_api
        execute_admin_api_query(query, **variables)
      when :customer_account_api
        execute_customer_account_api_query(query, **variables)
      else
        raise ArgumentError, "Unknown client type: #{@client_type}"
      end
    end

    # Executes a query against the Admin API
    def execute_admin_api_query(query, **variables)
      client = ActiveShopifyGraphQL.configuration.admin_api_client
      raise Error, "Admin API client not configured. Please configure it using ActiveShopifyGraphQL.configure" unless client

      client.execute(query, **variables)
    end

    # Executes a query against the Customer Account API
    def execute_customer_account_api_query(_query, **_variables)
      # Customer Account API implementation would go here
      # For now, raise an error since we'd need token handling
      raise NotImplementedError, "Customer Account API support needs token handling implementation"
    end
  end
end
