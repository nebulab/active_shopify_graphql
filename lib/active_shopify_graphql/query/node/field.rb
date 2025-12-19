# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Query
    class Node
      # Renders simple fields and nested fields with children.
      # Examples:
      #   - Simple: `id`
      #   - With alias: `customerId: id`
      #   - Nested: `defaultAddress { city country }`
      class Field < Node
        def to_s
          full_name = "#{field_name_with_alias}#{format_arguments}"

          return full_name unless has_children?

          nested_fields = render_children
          "#{full_name} { #{nested_fields.join(' ')} }"
        end
      end
    end
  end
end
