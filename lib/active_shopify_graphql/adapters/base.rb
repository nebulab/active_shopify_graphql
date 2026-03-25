# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Adapters
    # Base adapter class that defines the interface for executing GraphQL queries.
    # Subclass this to create custom adapters for different GraphQL clients.
    class Base
      # Execute a GraphQL query with the given variables.
      #
      # @param query [String] The GraphQL query string
      # @param variables [Hash] Variables to pass to the query
      # @return [Hash] The response from the GraphQL API
      # @raise [NotImplementedError] Subclasses must implement this method
      def execute(query, **variables)
        raise NotImplementedError, "#{self.class.name} must implement #execute"
      end
    end
  end
end
