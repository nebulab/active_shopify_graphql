# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Query
    # Builds complete GraphQL queries from a LoaderContext.
    # Handles both fragment construction and query wrapping.
    # Delegates rendering to polymorphic Node subclasses.
    class QueryBuilder
      attr_reader :context

      def initialize(context)
        @context = context
      end

      # === Class-level factory methods for building complete queries ===

      def self.build_single_record_query(context)
        builder = new(context)
        fragment = builder.build_fragment

        Node::SingleRecord.new(
          model_type: context.graphql_type,
          query_name: context.query_name,
          fragment_name: context.fragment_name,
          fragments: [fragment]
        ).to_s
      end

      # Build a query that doesn't require an ID parameter (e.g., Customer Account API's current customer)
      def self.build_current_customer_query(context, query_name: nil)
        builder = new(context)
        fragment = builder.build_fragment

        Node::CurrentCustomer.new(
          model_type: context.graphql_type,
          query_name: query_name || context.query_name,
          fragment_name: context.fragment_name,
          fragments: [fragment]
        ).to_s
      end

      def self.build_collection_query(context, query_name:, variables:, include_page_info: false)
        builder = new(context)
        fragment = builder.build_fragment

        Node::Collection.new(
          model_type: context.graphql_type,
          query_name: query_name,
          fragment_name: context.fragment_name,
          variables: variables,
          fragments: [fragment],
          include_page_info: include_page_info
        ).to_s
      end

      # Build a paginated collection query that includes pageInfo for cursor-based pagination
      def self.build_paginated_collection_query(context, query_name:, variables:)
        build_collection_query(context, query_name: query_name, variables: variables, include_page_info: true)
      end

      def self.build_connection_query(context, query_name:, variables:, parent_query: nil, singular: false)
        builder = new(context)
        fragment = builder.build_fragment

        if parent_query
          Node::NestedConnection.new(
            query_name: query_name,
            fragment_name: context.fragment_name,
            variables: variables,
            parent_query: parent_query,
            fragments: [fragment],
            singular: singular
          ).to_s
        else
          Node::RootConnection.new(
            query_name: query_name,
            fragment_name: context.fragment_name,
            variables: variables,
            fragments: [fragment],
            singular: singular
          ).to_s
        end
      end

      def self.normalize_includes(includes)
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

      def self.fragment_name(graphql_type)
        "#{graphql_type}Fragment"
      end

      # === Instance methods for building fragments ===

      # Build a complete fragment node with all fields and connections
      def build_fragment
        raise NotImplementedError, "#{@context.loader_class} must define attributes" if @context.defined_attributes.empty?

        fragment_node = Node::Fragment.new(
          name: @context.fragment_name,
          arguments: { on: @context.graphql_type }
        )

        # Add field nodes from attributes
        build_field_nodes.each { |node| fragment_node.add_child(node) }

        # Add connection nodes
        build_connection_nodes.each { |node| fragment_node.add_child(node) }

        fragment_node
      end

      # Build field nodes from attribute definitions
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

        # Convert tree to Node objects
        nodes_from_tree(path_tree) + aliased_field_nodes + metafield_nodes(metafield_aliases) + raw_graphql_nodes
      end

      # Build Node objects for all connections
      def build_connection_nodes
        return [] if @context.included_connections.empty?

        connections = @context.connections
        return [] if connections.empty?

        normalized_includes = self.class.normalize_includes(@context.included_connections)

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
        Node::Raw.new(
          name: "raw",
          arguments: { raw_graphql: aliased_raw_graphql }
        )
      end

      def build_aliased_field_node(attr_name, path)
        alias_name = attr_name.to_s
        # Only add alias if the attr_name differs from the GraphQL field name
        alias_name = nil if alias_name == path
        Node::Field.new(name: path, alias_name: alias_name)
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
            Node::Field.new(name: key)
          else
            children = nodes_from_tree(value)
            Node::Field.new(name: key, children: children)
          end
        end
      end

      def metafield_nodes(metafield_aliases)
        metafield_aliases.map do |alias_name, config|
          value_node = Node::Field.new(name: config[:value_field])
          Node::Field.new(
            name: "metafield",
            alias_name: alias_name,
            arguments: { namespace: config[:namespace], key: config[:key] },
            children: [value_node]
          )
        end
      end

      def build_connection_node(connection_config, nested_includes)
        connection_type = connection_config[:type] || :connection

        # Handle metaobject reference connections differently
        return build_metaobject_reference_node(connection_config, nested_includes) if connection_type == :metaobject_reference

        target_class = connection_config[:class_name].constantize
        target_context = @context.for_model(target_class, new_connections: nested_includes)

        # Build child nodes for the target model
        child_nodes = build_target_field_nodes(target_context, nested_includes)

        query_name = connection_config[:query_name]
        original_name = connection_config[:original_name]
        formatted_args = (connection_config[:default_arguments] || {}).transform_keys(&:to_sym)

        # Add alias if the connection name differs from the query name
        alias_name = original_name.to_s == query_name ? nil : original_name.to_s

        if connection_type == :singular
          Node::Singular.new(
            name: query_name,
            alias_name: alias_name,
            arguments: formatted_args,
            children: child_nodes
          )
        else
          Node::Connection.new(
            name: query_name,
            alias_name: alias_name,
            arguments: formatted_args,
            children: child_nodes
          )
        end
      end

      def build_target_field_nodes(target_context, nested_includes)
        # Build attribute nodes
        attribute_nodes = if target_context.defined_attributes.any?
                            QueryBuilder.new(target_context.for_model(target_context.model_class, new_connections: [])).build_field_nodes
                          else
                            [Node::Field.new(name: "id")]
                          end

        # Build nested connection nodes
        return attribute_nodes if nested_includes.empty?

        nested_builder = QueryBuilder.new(target_context)
        nested_connection_nodes = nested_builder.build_connection_nodes
        attribute_nodes + nested_connection_nodes
      end

      def build_metaobject_reference_node(connection_config, nested_includes)
        target_class = connection_config[:class_name].constantize
        original_name = connection_config[:original_name]

        # Build the metaobject fields
        metaobject_fields = build_metaobject_fields(target_class, nested_includes)

        # Build the reference fragment: reference { ... on Metaobject { fields } }
        reference_children = [
          Node::InlineFragment.new(
            name: "inline",
            arguments: { on: "Metaobject" },
            children: metaobject_fields
          )
        ]

        reference_node = Node::Field.new(name: "reference", children: reference_children)

        # Build the metafield query with the reference
        Node::Field.new(
          name: "metafield",
          alias_name: original_name.to_s,
          arguments: {
            namespace: connection_config[:metafield_namespace],
            key: connection_config[:metafield_key]
          },
          children: [reference_node]
        )
      end

      def build_metaobject_fields(target_class, _nested_includes)
        # Core metaobject fields
        core_fields = [
          Node::Field.new(name: "id"),
          Node::Field.new(name: "handle"),
          Node::Field.new(name: "type"),
          Node::Field.new(name: "displayName")
        ]

        # Get metaobject attributes from the target class
        metaobject_attributes = target_class.metaobject_attributes

        # Build field queries for each attribute
        field_nodes = metaobject_attributes.map do |_attr_name, config|
          field_key = config[:key]
          aliased_key = field_key.gsub(/[^a-zA-Z0-9_]/, '_')

          # Build: aliased_key: field(key: "field_key") { key value jsonValue }
          Node::Field.new(
            name: "field",
            alias_name: aliased_key,
            arguments: { key: field_key },
            children: [
              Node::Field.new(name: "key"),
              Node::Field.new(name: "value"),
              Node::Field.new(name: "jsonValue")
            ]
          )
        end

        core_fields + field_nodes
      end
    end
  end
end
