# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Query
    class Node
      # Renders a root-level connection query (no parent record).
      # Example:
      #   query {
      #     customers(first: 10) {
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
      class RootConnection < Node
        attr_reader :query_name, :fragment_name, :variables, :fragments, :singular

        def initialize(query_name:, fragment_name:, variables: {}, fragments: [], singular: false)
          @query_name = query_name
          @fragment_name = fragment_name
          @variables = variables
          @fragments = fragments
          @singular = singular
          super(name: query_name)
        end

        def to_s(*)
          if @singular
            render_singular_connection
          else
            render_nodes_connection
          end
        end

        private

        def render_singular_connection
          "#{fragments_string} query { #{query_name}#{field_signature} { ...#{fragment_name} } }"
        end

        def render_nodes_connection
          "#{fragments_string} query { #{query_name}#{field_signature} { #{PAGE_INFO_FIELDS} nodes { ...#{fragment_name} } } }"
        end

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
