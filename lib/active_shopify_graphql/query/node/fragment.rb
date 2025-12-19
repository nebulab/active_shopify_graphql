# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Query
    class Node
      # Renders GraphQL fragment definitions.
      # Example: `fragment CustomerFragment on Customer { id displayName email }`
      class Fragment < Node
        def to_s
          type_name = @arguments[:on]
          fields = render_children
          "fragment #{@name} on #{type_name} { #{fields.join(' ')} }"
        end
      end
    end
  end
end
