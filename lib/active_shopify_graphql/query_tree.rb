# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Builds complete GraphQL queries from a LoaderContext.
  # Refactored for Single Responsibility - only handles query string generation.
  # Fragment building is delegated to FragmentBuilder.
  class QueryTree
    # Keys whose string values should be wrapped in double quotes in inline GraphQ
    STRING_KEYS_NEEDING_QUOTES = %i[query after before].freeze
    PAGE_INFO_FIELDS = "pageInfo { hasNextPage hasPreviousPage startCursor endCursor }"

    attr_reader :context

    def initialize(context)
      @context = context
      @fragments = []
      @query_config = {}
    end

    # Class-level factory methods for building complete queries

    def self.build_single_record_query(context)
      new(context).tap do |tree|
        tree.add_fragment(FragmentBuilder.new(context).build)
        tree.set_query_config(
          type: :single_record,
          model_type: context.graphql_type,
          query_name: context.query_name,
          fragment_name: context.fragment_name
        )
      end.to_s
    end

    # Build a query that doesn't require an ID parameter (e.g., Customer Account API's current customer)
    def self.build_current_customer_query(context, query_name: nil)
      new(context).tap do |tree|
        tree.add_fragment(FragmentBuilder.new(context).build)
        tree.set_query_config(
          type: :current_customer,
          model_type: context.graphql_type,
          query_name: query_name || context.query_name,
          fragment_name: context.fragment_name
        )
      end.to_s
    end

    def self.build_collection_query(context, query_name:, variables:, connection_type: :nodes_only)
      new(context).tap do |tree|
        tree.add_fragment(FragmentBuilder.new(context).build)
        tree.set_query_config(
          type: :collection,
          model_type: context.graphql_type,
          query_name: query_name,
          fragment_name: context.fragment_name,
          variables: variables,
          connection_type: connection_type
        )
      end.to_s
    end

    # Build a paginated collection query that includes pageInfo for cursor-based pagination
    def self.build_paginated_collection_query(context, query_name:, variables:)
      new(context).tap do |tree|
        tree.add_fragment(FragmentBuilder.new(context).build)
        tree.set_query_config(
          type: :paginated_collection,
          model_type: context.graphql_type,
          query_name: query_name,
          fragment_name: context.fragment_name,
          variables: variables
        )
      end.to_s
    end

    def self.build_connection_query(context, query_name:, variables:, parent_query: nil, connection_type: :connection)
      new(context).tap do |tree|
        tree.add_fragment(FragmentBuilder.new(context).build)
        tree.set_query_config(
          type: :connection,
          query_name: query_name,
          fragment_name: context.fragment_name,
          variables: variables,
          parent_query: parent_query,
          connection_type: connection_type
        )
      end.to_s
    end

    # Delegate normalize_includes to FragmentBuilder
    def self.normalize_includes(includes)
      FragmentBuilder.normalize_includes(includes)
    end

    def self.fragment_name(graphql_type)
      "#{graphql_type}Fragment"
    end

    def add_fragment(fragment_node)
      @fragments << fragment_node
    end

    def set_query_config(config)
      @query_config = config
    end

    def to_s
      case @query_config[:type]
      when :single_record then render_single_record_query
      when :current_customer then render_current_customer_query
      when :collection then render_collection_query
      when :paginated_collection then render_paginated_collection_query
      when :connection then render_connection_query
      else ""
      end
    end

    private

    def compact?
      ActiveShopifyGraphQL.configuration.compact_queries
    end

    def fragments_string
      @fragments.map(&:to_s).join(compact? ? " " : "\n\n")
    end

    def field_signature(variables)
      params = build_field_parameters(variables.compact)
      params.empty? ? "" : "(#{params.join(', ')})"
    end

    def render_single_record_query
      type = @query_config[:model_type]
      query_name = @query_config[:query_name]
      fragment_name = @query_config[:fragment_name]

      if compact?
        "#{fragments_string} query get#{type}($id: ID!) { #{query_name}(id: $id) { ...#{fragment_name} } }"
      else
        "#{fragments_string}\n\nquery get#{type}($id: ID!) {\n  #{query_name}(id: $id) {\n    ...#{fragment_name}\n  }\n}\n"
      end
    end

    def render_current_customer_query
      type = @query_config[:model_type]
      query_name = @query_config[:query_name]
      fragment_name = @query_config[:fragment_name]

      if compact?
        "#{fragments_string} query getCurrent#{type} { #{query_name} { ...#{fragment_name} } }"
      else
        "#{fragments_string}\n\nquery getCurrent#{type} {\n  #{query_name} {\n    ...#{fragment_name}\n  }\n}\n"
      end
    end

    def render_collection_query
      type = @query_config[:model_type]
      query_name = @query_config[:query_name]
      fragment_name = @query_config[:fragment_name]
      variables = @query_config[:variables] || {}
      connection_type = @query_config[:connection_type] || :nodes_only

      field_sig = field_signature(variables)

      if compact?
        body = wrap_connection_body_compact(fragment_name, connection_type)
        "#{fragments_string} query get#{type.pluralize} { #{query_name}#{field_sig} { #{body} } }"
      else
        body = wrap_connection_body_formatted(fragment_name, connection_type, 2)
        "#{fragments_string}\nquery get#{type.pluralize} {\n  #{query_name}#{field_sig} {\n#{body}\n  }\n}\n"
      end
    end

    def render_paginated_collection_query
      type = @query_config[:model_type]
      query_name = @query_config[:query_name]
      fragment_name = @query_config[:fragment_name]
      variables = @query_config[:variables] || {}

      field_sig = field_signature(variables)

      if compact?
        "#{fragments_string} query get#{type.pluralize} { #{query_name}#{field_sig} { #{PAGE_INFO_FIELDS} nodes { ...#{fragment_name} } } }"
      else
        "#{fragments_string}\nquery get#{type.pluralize} {\n  #{query_name}#{field_sig} {\n#{PAGE_INFO_FIELDS}\n    nodes {\n      ...#{fragment_name}\n    }\n  }\n}\n"
      end
    end

    def render_connection_query
      query_name = @query_config[:query_name]
      fragment_name = @query_config[:fragment_name]
      variables = @query_config[:variables] || {}
      parent_query = @query_config[:parent_query]
      connection_type = @query_config[:connection_type] || :connection

      field_sig = field_signature(variables)

      if parent_query
        render_nested_connection_query(query_name, fragment_name, field_sig, parent_query, connection_type)
      else
        render_root_connection_query(query_name, fragment_name, field_sig, connection_type)
      end
    end

    def render_nested_connection_query(query_name, fragment_name, field_sig, parent_query, connection_type)
      if compact?
        body = wrap_connection_body_compact(fragment_name, connection_type)
        "#{fragments_string} query($id: ID!) { #{parent_query} { #{query_name}#{field_sig} { #{body} } } }"
      else
        body = wrap_connection_body_formatted(fragment_name, connection_type, 3)
        "#{fragments_string}\nquery($id: ID!) {\n  #{parent_query} {\n    #{query_name}#{field_sig} {\n#{body}\n    }\n  }\n}\n"
      end
    end

    def render_root_connection_query(query_name, fragment_name, field_sig, connection_type)
      if compact?
        body = wrap_connection_body_compact(fragment_name, connection_type)
        "#{fragments_string} query { #{query_name}#{field_sig} { #{body} } }"
      else
        body = wrap_connection_body_formatted(fragment_name, connection_type, 2)
        "#{fragments_string}\nquery {\n  #{query_name}#{field_sig} {\n#{body}\n  }\n}\n"
      end
    end

    def wrap_connection_body_compact(fragment_name, connection_type)
      case connection_type
      when :singular    then "...#{fragment_name}"
      when :nodes_only  then "nodes { ...#{fragment_name} }"
      else                   "edges { node { ...#{fragment_name} } }"
      end
    end

    def wrap_connection_body_formatted(fragment_name, connection_type, indent_level)
      indent = "  " * indent_level
      case connection_type
      when :singular
        "#{indent}...#{fragment_name}"
      when :nodes_only
        "#{indent}nodes {\n#{indent}  ...#{fragment_name}\n#{indent}}"
      else
        "#{indent}edges {\n#{indent}  node {\n#{indent}    ...#{fragment_name}\n#{indent}  }\n#{indent}}"
      end
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
