# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Loaders
    class AdminApiLoader < Loader
      def initialize(model_class = nil, selected_attributes: nil, included_connections: nil)
        super(model_class, selected_attributes: selected_attributes, included_connections: included_connections)
      end

      private

      def perform_graphql_query(query, **variables)
        client = ActiveShopifyGraphQL.configuration.admin_api_client
        raise Error, "Admin API client not configured. Please configure it using ActiveShopifyGraphQL.configure" unless client

        client.execute(query, **variables)
      end
    end
  end
end
