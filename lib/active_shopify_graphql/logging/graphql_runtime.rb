# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Logging
    # Thread-safe runtime and cost tracking for request summaries
    # Pattern borrowed from ActiveRecord's RuntimeRegistry
    module GraphqlRuntime
      module_function

      def runtime=(value)
        Thread.current[:active_shopify_graphql_runtime] = value
      end

      def runtime
        Thread.current[:active_shopify_graphql_runtime] ||= 0
      end

      def reset_runtime
        rt = runtime
        self.runtime = 0
        rt
      end

      def cost=(value)
        Thread.current[:active_shopify_graphql_cost] = value
      end

      def cost
        Thread.current[:active_shopify_graphql_cost] ||= 0
      end

      def reset_cost
        c = cost
        self.cost = 0
        c
      end

      def add(duration_ms:, cost:)
        self.runtime += duration_ms
        self.cost += cost if cost
      end
    end
  end
end
