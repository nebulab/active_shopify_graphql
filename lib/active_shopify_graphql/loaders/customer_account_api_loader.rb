# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Loaders
    class CustomerAccountApiLoader < Loader
      def initialize(model_class = nil, token = nil, selected_attributes: nil, included_connections: nil)
        super(model_class, selected_attributes: selected_attributes, included_connections: included_connections)
        @token = token
      end

      # Override to handle Customer queries that don't need an ID
      def graphql_query
        if context.graphql_type == 'Customer'
          Query::QueryBuilder.build_current_customer_query(context)
        else
          super
        end
      end

      # Override load_attributes to handle the Customer case
      def load_attributes(id = nil)
        variables = context.graphql_type == 'Customer' ? {} : { id: id }
        response_data = execute_query(graphql_query, **variables)

        return nil if response_data.nil?

        map_response_to_attributes(response_data)
      end

      def client
        client_class = ActiveShopifyGraphQL.configuration.customer_account_client_class
        raise Error, "Customer Account API client class not configured" unless client_class

        @client ||= client_class.from_config(@token)
      end

      def perform_graphql_query(query, **variables)
        log_query("Customer Account API", query, variables)
        client.query(query, variables)
      end
    end
  end
end
