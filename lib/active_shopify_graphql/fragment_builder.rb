# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Builds GraphQL fragments from model attributes and connections.
  class FragmentBuilder
    def initialize(context)
      @context = context
    end

    # Build a complete fragment node with all fields and connections
    def build
      raise NotImplementedError, "#{@context.loader_class} must define attributes" if @context.defined_attributes.empty?

      fragment_node = QueryNode.new(
        name: @context.fragment_name,
        arguments: { on: @context.graphql_type },
        node_type: :fragment
      )

      # Add field nodes from attributes
      build_field_nodes.each { |node| fragment_node.add_child(node) }

      # Add connection nodes
      build_connection_nodes.each { |node| fragment_node.add_child(node) }

      fragment_node
    end

    # Build field nodes from attribute definitions (protected for recursive calls)
    def build_field_nodes
      path_tree = {}
      metafield_aliases = {}
      raw_graphql_nodes = []
      aliased_field_nodes = []

      # Build a tree structure for nested paths
      @context.defined_attributes.each do |attr_name, config|
        if config[:raw_graphql]
          raw_graphql_nodes << build_raw_graphql_node(attr_name, config[:raw_graphql])
        elsif config[:is_metafield]
          store_metafield_config(metafield_aliases, config)
        else
          path = config[:path]
          if path.include?('.')
            # Nested path - use tree structure (shared prefixes)
            build_path_tree(path_tree, path)
          else
            # Simple path - add aliased field node
            aliased_field_nodes << build_aliased_field_node(attr_name, path)
          end
        end
      end

      # Convert tree to QueryNode objects
      nodes_from_tree(path_tree) + aliased_field_nodes + metafield_nodes(metafield_aliases) + raw_graphql_nodes
    end

    # Build QueryNode objects for all connections (protected for recursive calls)
    def build_connection_nodes
      return [] if @context.included_connections.empty?

      connections = @context.connections
      return [] if connections.empty?

      normalized_includes = normalize_includes(@context.included_connections)

      normalized_includes.filter_map do |connection_name, nested_includes|
        connection_config = connections[connection_name]
        next unless connection_config

        build_connection_node(connection_config, nested_includes)
      end
    end

    private

    def store_metafield_config(metafield_aliases, config)
      alias_name = config[:metafield_alias]
      value_field = config[:type] == :json ? 'jsonValue' : 'value'

      metafield_aliases[alias_name] = {
        namespace: config[:metafield_namespace],
        key: config[:metafield_key],
        value_field: value_field
      }
    end

    def build_raw_graphql_node(attr_name, raw_graphql)
      # Prepend alias to raw GraphQL for predictable response mapping
      aliased_raw_graphql = "#{attr_name}: #{raw_graphql}"
      QueryNode.new(
        name: "raw",
        arguments: { raw_graphql: aliased_raw_graphql },
        node_type: :raw
      )
    end

    def build_aliased_field_node(attr_name, path)
      alias_name = attr_name.to_s
      # Only add alias if the attr_name differs from the GraphQL field name
      alias_name = nil if alias_name == path
      QueryNode.new(name: path, alias_name: alias_name, node_type: :field)
    end

    def build_path_tree(path_tree, path)
      path_parts = path.split('.')
      current_level = path_tree

      path_parts.each_with_index do |part, index|
        if index == path_parts.length - 1
          current_level[part] = true
        else
          current_level[part] ||= {}
          current_level = current_level[part]
        end
      end
    end

    def nodes_from_tree(tree)
      tree.map do |key, value|
        if value == true
          QueryNode.new(name: key, node_type: :field)
        else
          children = nodes_from_tree(value)
          QueryNode.new(name: key, node_type: :field, children: children)
        end
      end
    end

    def metafield_nodes(metafield_aliases)
      metafield_aliases.map do |alias_name, config|
        value_node = QueryNode.new(name: config[:value_field], node_type: :field)
        QueryNode.new(
          name: "metafield",
          alias_name: alias_name,
          arguments: { namespace: config[:namespace], key: config[:key] },
          node_type: :field,
          children: [value_node]
        )
      end
    end

    def build_connection_node(connection_config, nested_includes)
      target_class = connection_config[:class_name].constantize
      target_context = @context.for_model(target_class, new_connections: nested_includes)

      # Build child nodes for the target model
      child_nodes = build_target_field_nodes(target_context, nested_includes)

      query_name = connection_config[:query_name]
      original_name = connection_config[:original_name]
      connection_type = connection_config[:type] || :connection
      formatted_args = (connection_config[:default_arguments] || {}).transform_keys(&:to_sym)

      # Add alias if the connection name differs from the query name
      alias_name = original_name.to_s == query_name ? nil : original_name.to_s

      node_type = connection_type == :singular ? :singular : :connection
      QueryNode.new(
        name: query_name,
        alias_name: alias_name,
        arguments: formatted_args,
        node_type: node_type,
        children: child_nodes
      )
    end

    def build_target_field_nodes(target_context, nested_includes)
      # Build attribute nodes
      attribute_nodes = if target_context.defined_attributes.any?
                          FragmentBuilder.new(target_context.with_connections([])).build_field_nodes
                        else
                          [QueryNode.new(name: "id", node_type: :field)]
                        end

      # Build nested connection nodes
      return attribute_nodes if nested_includes.empty?

      nested_builder = FragmentBuilder.new(target_context)
      nested_connection_nodes = nested_builder.build_connection_nodes
      attribute_nodes + nested_connection_nodes
    end

    # Normalize includes from various formats to a consistent hash structure
    def normalize_includes(includes)
      includes = Array(includes)
      includes.each_with_object({}) do |inc, normalized|
        case inc
        when Hash
          inc.each do |key, value|
            key = key.to_sym
            normalized[key] ||= []
            case value
            when Hash then normalized[key] << value
            when Array then normalized[key].concat(value)
            else normalized[key] << value
            end
          end
        when Symbol, String
          normalized[inc.to_sym] ||= []
        end
      end
    end

    class << self
      # Expose for external use (QueryTree needs this)
      def normalize_includes(includes)
        includes = Array(includes)
        includes.each_with_object({}) do |inc, normalized|
          case inc
          when Hash
            inc.each do |key, value|
              key = key.to_sym
              normalized[key] ||= []
              case value
              when Hash then normalized[key] << value
              when Array then normalized[key].concat(value)
              else normalized[key] << value
              end
            end
          when Symbol, String
            normalized[inc.to_sym] ||= []
          end
        end
      end
    end
  end
end
