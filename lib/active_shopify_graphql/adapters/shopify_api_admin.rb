# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Adapters
    # Adapter for ShopifyAPI gem's Admin GraphQL client.
    # Uses the active session from ShopifyAPI::Context.
    class ShopifyApiAdmin < Base
      def execute(query, **variables)
        session = ShopifyAPI::Context.active_session
        client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)
        response = client.query(query: query, variables: variables)

        raise_errors_if_present(response)

        response.body["data"]
      end

      private

      def raise_errors_if_present(response)
        errors = response.body["errors"]
        return unless errors

        formatted_errors = errors.map { |error| error["message"] }.join(", ")
        raise StandardError, "GraphQL errors: #{formatted_errors}"
      end
    end
  end
end
