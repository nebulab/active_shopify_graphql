# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Query
    class Node
      # Renders a query that doesn't require an ID parameter.
      # Used for Customer Account API's current customer query.
      # Example:
      #   query getCurrentCustomer {
      #     customer {
      #       ...CustomerFragment
      #     }
      #   }
      class CurrentCustomer < Node
        attr_reader :model_type, :query_name, :fragment_name, :fragments

        def initialize(model_type:, query_name:, fragment_name:, fragments: [])
          @model_type = model_type
          @query_name = query_name
          @fragment_name = fragment_name
          @fragments = fragments
          super(name: query_name)
        end

        def to_s
          "#{fragments_string} query getCurrent#{model_type} { #{query_name} { ...#{fragment_name} } }"
        end

        private

        def fragments_string
          @fragments.map(&:to_s).join(' ')
        end
      end
    end
  end
end
