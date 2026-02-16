# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Logging
    # Adds GraphQL runtime and cost to the Rails request log
    # Pattern borrowed from ActiveRecord::Railties::ControllerRuntime
    #
    # Include this module in your ApplicationController or via an initializer:
    #
    #   ActiveSupport.on_load(:action_controller) do
    #     include ActiveShopifyGraphQL::Logging::GraphqlControllerRuntime
    #   end
    #
    module GraphqlControllerRuntime
      extend ActiveSupport::Concern

      module ClassMethods
        def log_process_action(payload)
          messages = super
          runtime = payload[:graphql_runtime]
          cost = payload[:graphql_cost]

          if runtime&.positive?
            cost_info = cost&.positive? ? ", #{cost.round} cost" : ""
            messages << "GraphQL: #{runtime.round(1)}ms#{cost_info}"
          end

          messages
        end
      end

      private

      def append_info_to_payload(payload)
        super
        payload[:graphql_runtime] = GraphqlRuntime.reset_runtime
        payload[:graphql_cost] = GraphqlRuntime.reset_cost
      end
    end
  end
end
