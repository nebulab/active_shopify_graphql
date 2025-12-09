# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Provides low-level GraphQL query structure building primitives
  # Does not know about specific query types (record/collection/connection)
  # Just provides tools to wrap fields in various GraphQL structures
  class Query
    def initialize
      @compact = ActiveShopifyGraphQL.configuration.compact_queries
    end

    # Wrap fields in a connection structure (edges { node { ... } })
    def wrap_in_connection(field_signature:, fields:)
      if @compact
        "#{field_signature} { edges { node { #{fields} } } }"
      else
        indent = "          "
        "#{field_signature} {\n#{indent}edges {\n#{indent}  node {\n#{indent}    #{fields}\n#{indent}  }\n#{indent}}\n        }"
      end
    end

    # Wrap fields in a singular structure (just { ... })
    def wrap_in_singular(field_signature:, fields:)
      if @compact
        "#{field_signature} { #{fields} }"
      else
        indent = "          "
        "#{field_signature} {\n#{indent}  #{fields}\n        }"
      end
    end

    # Wrap an inner query in a parent query context
    def wrap_in_parent(parent_query:, inner_query:, query_signature: "")
      if @compact
        "query#{query_signature} { #{parent_query} { #{inner_query} } }"
      else
        "query#{query_signature} {\n      #{parent_query} {\n        #{inner_query}\n      }\n    }"
      end
    end

    # Wrap fields in a root-level query
    def wrap_in_root_query(field_query:, fields:, query_signature: "")
      if @compact
        "query#{query_signature} { #{field_query} { #{fields} } }"
      else
        "query#{query_signature} {\n      #{field_query} {\n        #{fields}\n      }\n    }"
      end
    end

    # Wrap fragment reference in query structure
    def wrap_fragment_in_query(fragment_string:, fragment_name:, query_name:, query_signature:)
      if @compact
        "#{fragment_string} query #{query_signature} { #{query_name} { ...#{fragment_name} } }"
      else
        "#{fragment_string}\n\nquery #{query_signature} {\n  #{query_name} {\n    ...#{fragment_name}\n  }\n}\n"
      end
    end
  end
end
