# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Adapters
    # Adapter for ShopifyAPI gem's Customer Account GraphQL client.
    # Requires an access token to be provided at initialization.
    class ShopifyApiCustomerAccount < Base
      def initialize(access_token:)
        super()
        @access_token = access_token
      end

      def execute(query, **variables)
        client = ShopifyAPI::Clients::Graphql::CustomerAccount.new(access_token: @access_token)
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
