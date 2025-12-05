# frozen_string_literal: true

module ActiveShopifyGraphQL
  class CustomerAccountApiLoader < Loader
    def initialize(model_class = nil, token = nil, selected_attributes: nil, included_connections: nil)
      super(model_class, selected_attributes: selected_attributes, included_connections: included_connections)
      @token = token
    end

    # Override to handle Customer queries that don't need an ID
    def graphql_query(model_type = nil)
      type = model_type || graphql_type
      if type == 'Customer'
        # Customer Account API doesn't need ID for customer queries - token identifies the customer
        customer_only_query(type)
      else
        # For other types, use the standard query with ID
        super(type)
      end
    end

    # Override load_attributes to handle the Customer case
    def load_attributes(id = nil)
      type = graphql_type
      query = graphql_query(type)

      # For Customer queries, we don't need variables; for others, we need the ID
      variables = type == 'Customer' ? {} : { id: id }

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

    def perform_graphql_query(query, **variables)
      # The customer access token is already set in the client's headers
      client.query(query, variables)
    end

    # Builds a customer-only query (no ID parameter needed)
    def customer_only_query(model_type = nil)
      type = model_type || graphql_type
      query_name_value = query_name(type)
      fragment_name_value = fragment_name(type)

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
