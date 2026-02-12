# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Adapters
    # Adapter that wraps a user-provided callable (proc, lambda, or block).
    # This allows users to define custom query execution logic without
    # creating a full adapter class.
    #
    # @example Using a lambda
    #   adapter = Proc.new(->(query, **variables) {
    #     MyGraphQLClient.execute(query, variables)
    #   })
    #
    # @example Using a block
    #   adapter = Proc.new { |query, **variables|
    #     MyGraphQLClient.execute(query, variables)
    #   }
    class Proc < Base
      # @param callable [Proc, #call] A callable object that accepts (query, **variables)
      def initialize(callable = nil, &block)
        @callable = callable || block
        raise ArgumentError, "Must provide a callable or block" unless @callable.respond_to?(:call)
      end

      # Execute a GraphQL query by delegating to the wrapped callable.
      #
      # @param query [String] The GraphQL query string
      # @param variables [Hash] Variables to pass to the query
      # @return [Hash] The response from the callable
      def execute(query, **variables)
        @callable.call(query, **variables)
      end
    end
  end
end
