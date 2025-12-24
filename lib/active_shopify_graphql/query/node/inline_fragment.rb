# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Query
    class Node
      # Renders GraphQL inline fragment definitions.
      # Example: `... on Metaobject { id handle type }`
      class InlineFragment < Node
        def to_s
          type_name = @arguments[:on]
          fields = render_children
          "... on #{type_name} { #{fields.join(' ')} }"
        end
      end
    end
  end
end
