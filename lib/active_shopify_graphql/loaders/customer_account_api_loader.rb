# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Loaders
    class CustomerAccountApiLoader < Loader
      def initialize(model_class = nil, token = nil, selected_attributes: nil, included_connections: nil)
        super(model_class, selected_attributes: selected_attributes, included_connections: included_connections)
        @token = token
      end

      # Override load_attributes to handle the Customer case
      def load_attributes(id = nil)
        query = if context.graphql_type == 'Customer'
                  Query::QueryBuilder.build_current_customer_query(context)
                else
                  Query::QueryBuilder.build_single_record_query(context)
                end
        variables = context.graphql_type == 'Customer' ? {} : { id: id }
        response_data = execute_query(query, **variables)

        return nil if response_data.nil?

        map_response_to_attributes(response_data)
      end

      def perform_graphql_query(query, **variables)
        config = ActiveShopifyGraphQL.configuration

        # Try adapter first (new approach)
        if config.customer_account_api_adapter
          adapter = instantiate_adapter(config.customer_account_api_adapter)
          return adapter.execute(query, **variables)
        end

        # Fall back to executor for backward compatibility
        return config.customer_account_api_executor.call(query, @token, **variables) if config.customer_account_api_executor

        raise Error, "Customer Account API adapter not configured. Please configure it using ActiveShopifyGraphQL.configure"
      end

      def initialization_args
        [@token]
      end

      private

      def instantiate_adapter(adapter_or_class)
        # If it responds to :new, treat it as a class that needs instantiation
        if adapter_or_class.respond_to?(:new)
          adapter_or_class.new(access_token: @token)
        else
          # Already an instance, use it as-is
          adapter_or_class
        end
      end
    end
  end
end
