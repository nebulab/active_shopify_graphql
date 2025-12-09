# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Represents the complete query tree structure
  class QueryTree
    def initialize
      @fragments = []
      @query_config = {}
    end

    # Class-level factory methods for building complete queries from loader configuration

    # Build a complete single-record query (find by ID)
    def self.build_single_record_query(graphql_type:, loader_class:, defined_attributes:, model_class:, included_connections:)
      new.tap do |tree|
        tree.add_fragment(tree.build_fragment_node(
                            graphql_type: graphql_type,
                            loader_class: loader_class,
                            defined_attributes: defined_attributes,
                            model_class: model_class,
                            included_connections: included_connections
                          ))
        tree.set_query_config(
          type: :single_record,
          model_type: graphql_type,
          query_name: graphql_type.downcase,
          fragment_name: fragment_name(graphql_type)
        )
      end.to_s
    end

    # Build a complete collection query (root-level search/where)
    def self.build_collection_query(graphql_type:, loader_class:, defined_attributes:, model_class:, included_connections:, query_name:, variables:, connection_type: :nodes_only)
      new.tap do |tree|
        tree.add_fragment(tree.build_fragment_node(
                            graphql_type: graphql_type,
                            loader_class: loader_class,
                            defined_attributes: defined_attributes,
                            model_class: model_class,
                            included_connections: included_connections
                          ))
        tree.set_query_config(
          type: :collection,
          model_type: graphql_type,
          query_name: query_name,
          fragment_name: fragment_name(graphql_type),
          variables: variables,
          connection_type: connection_type
        )
      end.to_s
    end

    # Build a complete connection query
    def self.build_connection_query(graphql_type:, loader_class:, defined_attributes:, model_class:, included_connections:, query_name:, variables:, parent_query: nil, connection_type: :connection)
      new.tap do |tree|
        tree.add_fragment(tree.build_fragment_node(
                            graphql_type: graphql_type,
                            loader_class: loader_class,
                            defined_attributes: defined_attributes,
                            model_class: model_class,
                            included_connections: included_connections
                          ))
        tree.set_query_config(
          type: :connection,
          query_name: query_name,
          fragment_name: fragment_name(graphql_type),
          variables: variables,
          parent_query: parent_query,
          connection_type: connection_type
        )
      end.to_s
    end

    # Helper: Get query name for a GraphQL type
    def self.query_name(graphql_type)
      graphql_type.downcase
    end

    # Helper: Get fragment name for a GraphQL type
    def self.fragment_name(graphql_type)
      "#{graphql_type}Fragment"
    end

    # Build a fragment node (class method wrapper)
    def self.build_fragment_node(graphql_type:, loader_class:, defined_attributes:, model_class:, included_connections:)
      new.build_fragment_node(
        graphql_type: graphql_type,
        loader_class: loader_class,
        defined_attributes: defined_attributes,
        model_class: model_class,
        included_connections: included_connections
      )
    end

    # Normalize includes from various formats to a consistent hash structure
    # Handles: [:orders], [{ orders: :line_items }], [{ orders: [:line_items] }], [{ orders: { line_items: :product } }]
    def self.normalize_includes(includes)
      includes = Array(includes)
      includes.each_with_object({}) do |inc, normalized|
        case inc
        when Hash
          inc.each do |key, value|
            key = key.to_sym
            normalized[key] ||= []
            # Preserve hash structure for nested includes
            case value
            when Hash
              normalized[key] << value
            when Array
              normalized[key].concat(value)
            else
              normalized[key] << value
            end
          end
        when Symbol, String
          normalized[inc.to_sym] ||= []
        end
      end
    end

    def add_fragment(fragment_node)
      @fragments << fragment_node
    end

    def set_query_config(config)
      @query_config = config
    end

    # Build a fragment node
    def build_fragment(name:, graphql_type:)
      QueryNode.new(
        name: name,
        arguments: { on: graphql_type },
        node_type: :fragment
      )
    end

    # Build a complete fragment node with all fields and connections
    # This is the core fragment-building logic moved from Fragment class
    def build_fragment_node(graphql_type:, loader_class:, defined_attributes:, model_class:, included_connections:)
      raise NotImplementedError, "#{loader_class} must define attributes" if defined_attributes.empty?

      fragment_name = "#{graphql_type}Fragment"
      fragment_node = build_fragment(name: fragment_name, graphql_type: graphql_type)

      # Add field nodes from attributes
      build_field_nodes_from_attributes(defined_attributes).each { |node| fragment_node.add_child(node) }

      # Add connection nodes
      build_connection_nodes(
        model_class: model_class,
        included_connections: included_connections,
        loader_class: loader_class
      ).each { |node| fragment_node.add_child(node) }

      fragment_node
    end

    # Build field nodes from attribute definitions
    def build_field_nodes_from_attributes(attributes)
      path_tree = {}
      metafield_aliases = {}

      # Build a tree structure for nested paths
      attributes.each_value do |config|
        if config[:is_metafield]
          # Handle metafield attributes specially
          alias_name = config[:metafield_alias]
          namespace = config[:metafield_namespace]
          key = config[:metafield_key]
          value_field = config[:type] == :json ? 'jsonValue' : 'value'

          # Store metafield definition for later insertion
          metafield_aliases[alias_name] = {
            namespace: namespace,
            key: key,
            value_field: value_field
          }
        else
          # Handle regular attributes - build path tree
          path_parts = config[:path].split('.')
          current_level = path_tree

          path_parts.each_with_index do |part, index|
            if index == path_parts.length - 1
              # Leaf node
              current_level[part] = true
            else
              # Branch node
              current_level[part] ||= {}
              current_level = current_level[part]
            end
          end
        end
      end

      # Convert tree to QueryNode objects
      regular_nodes = build_nodes_from_tree(path_tree)

      # Build metafield nodes
      metafield_nodes = metafield_aliases.map do |alias_name, config|
        value_node = QueryNode.new(name: config[:value_field], node_type: :field)
        QueryNode.new(
          name: "metafield",
          alias_name: alias_name,
          arguments: { namespace: config[:namespace], key: config[:key] },
          node_type: :field,
          children: [value_node]
        )
      end

      regular_nodes + metafield_nodes
    end

    # Convert path tree to QueryNode objects
    def build_nodes_from_tree(tree)
      tree.map do |key, value|
        if value == true
          # Leaf node - simple field
          QueryNode.new(name: key, node_type: :field)
        else
          # Branch node - nested selection
          children = build_nodes_from_tree(value)
          QueryNode.new(name: key, node_type: :field, children: children)
        end
      end
    end

    # Build QueryNode objects for all connections
    def build_connection_nodes(model_class:, included_connections:, loader_class:)
      return [] if included_connections.empty? || !model_class.respond_to?(:connections)

      connections = model_class.connections
      normalized_includes = normalize_includes(included_connections)

      normalized_includes.map do |connection_name, nested_includes|
        connection_config = connections[connection_name]
        next unless connection_config

        # Get the target model class to determine its fragment
        target_class = connection_config[:class_name].constantize

        # Create a loader for the target model to get its attributes
        target_loader = loader_class.new(target_class, included_connections: nested_includes)

        # Recursively build child nodes for the target model
        child_nodes = build_target_field_nodes(
          target_loader: target_loader,
          target_class: target_class,
          nested_includes: nested_includes,
          loader_class: loader_class
        )

        # Build connection node with GraphQL connection syntax
        query_name = connection_config[:query_name]
        connection_type = connection_config[:type] || :connection
        query_args = connection_config[:default_arguments] || {}

        # Format arguments
        formatted_args = query_args.transform_keys(&:to_sym)

        if connection_type == :singular
          QueryNode.new(
            name: query_name,
            arguments: formatted_args,
            node_type: :singular,
            children: child_nodes
          )
        else
          QueryNode.new(
            name: query_name,
            arguments: formatted_args,
            node_type: :connection,
            children: child_nodes
          )
        end
      end.compact
    end

    # Build field nodes for a target model (used in connections)
    def build_target_field_nodes(target_loader:, target_class:, nested_includes:, loader_class:)
      # Build attribute nodes
      attribute_nodes = if target_class.respond_to?(:attributes_for_loader) && target_class.attributes_for_loader(loader_class).any?
                          build_field_nodes_from_attributes(target_loader.defined_attributes)
                        else
                          # Fall back to basic fields if no attributes defined
                          [QueryNode.new(name: "id", node_type: :field)]
                        end

      # Build nested connection nodes
      if nested_includes.any?
        nested_connection_nodes = build_connection_nodes(
          model_class: target_class,
          included_connections: nested_includes,
          loader_class: target_loader.class
        )
        attribute_nodes + nested_connection_nodes
      else
        attribute_nodes
      end
    end

    # Normalize includes - delegates to class method
    def normalize_includes(includes)
      self.class.normalize_includes(includes)
    end

    # Convert the entire tree to a GraphQL string
    def to_s
      case @query_config[:type]
      when :single_record then render_single_record_query
      when :collection    then render_collection_query
      when :connection    then render_connection_query
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
      when String then key.to_sym == :query ? "\"#{value}\"" : value
      else value.to_s
      end
    end
  end
end
