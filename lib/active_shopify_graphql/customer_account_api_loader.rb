# frozen_string_literal: true

module ActiveShopifyGraphQL
  class CustomerAccountApiLoader < Loader
    def initialize(token)
      @token = token
    end

    # Override to handle Customer queries that don't need an ID
    def graphql_query(model_type = 'Customer')
      if model_type == 'Customer'
        # Customer Account API doesn't need ID for customer queries - token identifies the customer
        customer_only_query(model_type)
      else
        # For other types, use the standard query with ID
        super(model_type)
      end
    end

    # Override load_attributes to handle the Customer case
    def load_attributes(id = nil, model_type = 'Customer')
      query = graphql_query(model_type)

      # For Customer queries, we don't need variables; for others, we need the ID
      variables = model_type == 'Customer' ? {} : { id: id }

      response_data = execute_graphql_query(query, **variables)

      return nil if response_data.nil?

      map_response_to_attributes(response_data)
    end

    private

    def client
      client_class = ActiveShopifyGraphQL.configuration.customer_account_client_class
      raise Error, "Customer Account API client class not configured. Please configure it using ActiveShopifyGraphQL.configure" unless client_class

      @client ||= ActiveShopifyGraphQL.configuration.customer_account_client_class.from_config(@token)
    end

    def execute_graphql_query(query, **variables)
      # The customer access token is already set in the client's headers
      client.query(query, variables)
    end

    # Builds a customer-only query (no ID parameter needed)
    def customer_only_query(model_type)
      query_name_value = query_name(model_type)
      fragment_name_value = fragment_name(model_type)

      <<~GRAPHQL
        #{fragment}
        query getCurrentCustomer {
          #{query_name_value} {
            ...#{fragment_name_value}
          }
        }
      GRAPHQL
    end
  end
end
