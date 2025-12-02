# frozen_string_literal: true

module ActiveShopifyGraphQL
  class AdminApiLoader < Loader
    def initialize(model_class = nil, selected_attributes: nil)
      super(model_class, selected_attributes: selected_attributes)
    end

    private

    def execute_graphql_query(query, **variables)
      client = ActiveShopifyGraphQL.configuration.admin_api_client
      raise Error, "Admin API client not configured. Please configure it using ActiveShopifyGraphQL.configure" unless client

      client.execute(query, **variables)
    end
  end
end
