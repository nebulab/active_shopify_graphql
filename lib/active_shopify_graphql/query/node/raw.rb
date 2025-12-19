# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Query
    class Node
      # Renders raw GraphQL strings verbatim.
      # Used for custom GraphQL snippets that don't fit other node types.
      class Raw < Node
        def to_s(*)
          @arguments[:raw_graphql]
        end
      end
    end
  end
end
