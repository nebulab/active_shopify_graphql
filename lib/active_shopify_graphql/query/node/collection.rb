# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Query
    class Node
      # Renders a collection query with optional pagination.
      # Example without pagination:
      #   query getCustomers {
      #     customers(first: 10) {
      #       nodes {
      #         ...CustomerFragment
      #       }
      #     }
      #   }
      #
      # Example with pagination:
      #   query getCustomers {
      #     customers(first: 10, after: "cursor") {
      #       pageInfo {
      #         hasNextPage
      #         hasPreviousPage
      #         startCursor
      #         endCursor
      #       }
      #       nodes {
      #         ...CustomerFragment
      #       }
      #     }
      #   }
      class Collection < Node
        PAGE_INFO_FIELDS = "pageInfo { hasNextPage hasPreviousPage startCursor endCursor }"
        STRING_KEYS_NEEDING_QUOTES = %i[query after before].freeze

        attr_reader :model_type, :query_name, :fragment_name, :variables, :fragments, :include_page_info

        def initialize(model_type:, query_name:, fragment_name:, variables: {}, fragments: [], include_page_info: false)
          @model_type = model_type
          @query_name = query_name
          @fragment_name = fragment_name
          @variables = variables
          @fragments = fragments
          @include_page_info = include_page_info
          super(name: query_name)
        end

        def to_s
          parts = [fragments_string, "query get#{model_type.pluralize} { #{query_name}#{field_signature} {"]
          parts << PAGE_INFO_FIELDS if @include_page_info
          parts << "nodes { ...#{fragment_name} }"
          parts << "} }"
          parts.join(' ')
        end

        private

        def fragments_string
          @fragments.map(&:to_s).join(' ')
        end

        def field_signature
          params = build_field_parameters(@variables.compact)
          params.empty? ? "" : "(#{params.join(', ')})"
        end

        def build_field_parameters(variables)
          variables.map do |key, value|
            "#{key.to_s.camelize(:lower)}: #{format_inline_value(key, value)}"
          end
        end

        def format_inline_value(key, value)
          case value
          when Integer, TrueClass, FalseClass then value.to_s
          when String then STRING_KEYS_NEEDING_QUOTES.include?(key.to_sym) ? "\"#{value}\"" : value
          else value.to_s
          end
        end
      end
    end
  end
end
