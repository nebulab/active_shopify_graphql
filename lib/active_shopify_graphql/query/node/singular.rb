# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Query
    class Node
      # Renders singular association fields (has_one relationships).
      # Example: `defaultAddress { city country zip }`
      class Singular < Node
        def to_s
          nested_fields = render_children
          "#{field_name_with_alias}#{format_arguments} { #{nested_fields.join(' ')} }"
        end
      end
    end
  end
end
