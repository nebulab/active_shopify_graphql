# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Loaders
    class AdminApiLoader < Loader
      def initialize(model_class = nil, selected_attributes: nil, included_connections: nil)
        super(model_class, selected_attributes: selected_attributes, included_connections: included_connections)
      end

      def perform_graphql_query(query, **variables)
        log_query(query, variables) if should_log?

        client = ActiveShopifyGraphQL.configuration.admin_api_client
        raise Error, "Admin API client not configured. Please configure it using ActiveShopifyGraphQL.configure" unless client

        client.execute(query, **variables)
      end

      private

      def should_log?
        ActiveShopifyGraphQL.configuration.log_queries && ActiveShopifyGraphQL.configuration.logger
      end

      def log_query(query, variables)
        logger = ActiveShopifyGraphQL.configuration.logger
        logger.info("ActiveShopifyGraphQL Query (Admin API):\n#{query}")
        logger.info("ActiveShopifyGraphQL Variables:\n#{variables}")
      end
    end
  end
end
