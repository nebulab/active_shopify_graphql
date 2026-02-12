# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Loaders
    class AdminApiLoader < Loader
      def perform_graphql_query(query, **variables)
        adapter = ActiveShopifyGraphQL.configuration.adapter_for(:admin_api)
        raise Error, "Admin API adapter not configured. Please configure it using ActiveShopifyGraphQL.configure" unless adapter

        adapter.execute(query, **variables)
      end
    end
  end
end
