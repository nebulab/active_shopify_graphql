# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Logging
    # Logs GraphQL queries with timing and cost information
    # Uses ActiveSupport::LogSubscriber for consistent Rails-style log formatting
    class GraphqlLogger < ActiveSupport::LogSubscriber
      YELLOW = 33
      GREEN = 32
      BLUE = 34
      CYAN = 36
      MAGENTA = 35

      def self.log(query:, duration_ms:, cost:, variables:)
        new.log(query:, duration_ms:, cost:, variables:)
      end

      def log(query:, duration_ms:, cost:, variables:)
        GraphqlRuntime.add(duration_ms:, cost: cost&.dig("requestedQueryCost"))

        name = color("  GraphQL (#{duration_ms.round(1)}ms)", YELLOW, bold: true)
        colored_query = color(query.gsub(/\s+/, " ").strip, graphql_color(query), bold: true)
        binds = variables.present? ? "  #{variables.inspect}" : ""

        cost_info = "\n  ↳ cost: #{cost}" if cost
        debug "#{name}  #{colored_query}#{binds}#{cost_info}"
      end

      private

      def graphql_color(query)
        case query
        when /\A\s*mutation/i then GREEN
        when /\A\s*query/i then BLUE
        when /\A\s*subscription/i then CYAN
        else MAGENTA
        end
      end
    end
  end
end
