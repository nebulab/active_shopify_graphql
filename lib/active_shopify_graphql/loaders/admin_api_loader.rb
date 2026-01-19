# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Loaders
    class AdminApiLoader < Loader
      def perform_graphql_query(query, **variables)
        executor = ActiveShopifyGraphQL.configuration.admin_api_executor
        raise Error, "Admin API executor not configured. Please configure it using ActiveShopifyGraphQL.configure" unless executor

        executor.call(query, **variables)
      end
    end
  end
end
