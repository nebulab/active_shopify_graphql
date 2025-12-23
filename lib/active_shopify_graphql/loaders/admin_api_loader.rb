# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Loaders
    class AdminApiLoader < Loader
      def perform_graphql_query(query, **variables)
        log_query("Admin API", query, variables)

        client = ActiveShopifyGraphQL.configuration.admin_api_client
        raise Error, "Admin API client not configured. Please configure it using ActiveShopifyGraphQL.configure" unless client

        client.execute(query, **variables)
      end
    end
  end
end
