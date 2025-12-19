# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Query
    class Node
      # Renders connection fields using the nodes pattern.
      # Example: `orders(first: 10) { nodes { id createdAt } }`
      class Connection < Node
        def to_s
          nested_fields = render_children
          "#{field_name_with_alias}#{format_arguments} { nodes { #{nested_fields.join(' ')} } }"
        end
      end
    end
  end
end
