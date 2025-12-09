# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Represents a node in the GraphQL query tree
  # This allows building the complete query structure before converting to a string
  class QueryNode
    attr_reader :name, :arguments, :children, :node_type, :alias_name

    # @param name [String] The field name (e.g., 'id', 'displayName', 'orders')
    # @param alias_name [String] Optional field alias (e.g., 'myAlias' for 'myAlias: fieldName')
    # @param arguments [Hash] Field arguments (e.g., { first: 10, sortKey: 'CREATED_AT' })
    # @param node_type [Symbol] Type of node: :field, :connection, :singular, :fragment
    # @param children [Array<QueryNode>] Child nodes for nested structures
    def initialize(name:, alias_name: nil, arguments: {}, node_type: :field, children: [])
      @name = name
      @alias_name = alias_name
      @arguments = arguments
      @node_type = node_type
      @children = children
    end

    # Add a child node
    def add_child(node)
      @children << node
      node
    end

    # Check if node has children
    def has_children?
      @children.any?
    end

    # Convert node to GraphQL string
    def to_s(indent_level: 0)
      case @node_type
      when :field
        render_field(indent_level: indent_level)
      when :connection
        render_connection(indent_level: indent_level)
      when :singular
        render_singular(indent_level: indent_level)
      when :fragment
        render_fragment
      else
        raise ArgumentError, "Unknown node type: #{@node_type}"
      end
    end

    private

    def compact?
      ActiveShopifyGraphQL.configuration.compact_queries
    end

    def render_field(indent_level:)
      # Simple field with no children
      field_name = @alias_name ? "#{@alias_name}: #{@name}" : @name
      args_string = format_arguments
      full_name = "#{field_name}#{args_string}"

      return full_name unless has_children?

      # Field with nested structure (e.g., defaultAddress { city })
      indent = compact? ? "" : "  " * indent_level
      nested_indent = compact? ? "" : "  " * (indent_level + 1)

      nested_fields = @children.map { |child| child.to_s(indent_level: indent_level + 1) }

      if compact?
        "#{full_name} { #{nested_fields.join(' ')} }"
      else
        separator = "\n"
        "#{full_name} {#{separator}#{nested_indent}#{nested_fields.join("\n#{nested_indent}")}#{separator}#{indent}}"
      end
    end

    def render_connection(indent_level:)
      args_string = format_arguments

      indent = compact? ? "" : "  " * indent_level
      nested_indent = compact? ? "" : "  " * (indent_level + 1)

      # Build nested fields from children
      nested_fields = @children.map { |child| child.to_s(indent_level: indent_level + 2) }
      fields_string = nested_fields.join(compact? ? " " : "\n#{nested_indent}  ")

      if compact?
        "#{@name}#{args_string} { edges { node { #{fields_string} } } }"
      else
        <<~GRAPHQL.strip
          #{@name}#{args_string} {
          #{nested_indent}edges {
          #{nested_indent}  node {
          #{nested_indent}    #{fields_string}
          #{nested_indent}  }
          #{nested_indent}}
          #{indent}}
        GRAPHQL
      end
    end

    def render_singular(indent_level:)
      args_string = format_arguments

      indent = compact? ? "" : "  " * indent_level
      nested_indent = compact? ? "" : "  " * (indent_level + 1)

      # Build nested fields from children
      nested_fields = @children.map { |child| child.to_s(indent_level: indent_level + 1) }
      fields_string = nested_fields.join(compact? ? " " : "\n#{nested_indent}")

      if compact?
        "#{@name}#{args_string} { #{fields_string} }"
      else
        "#{@name}#{args_string} {\n#{nested_indent}#{fields_string}\n#{indent}}"
      end
    end

    def render_fragment
      # Fragment fields are the children
      fields = @children.map { |child| child.to_s(indent_level: 0) }
      all_fields = fields.join(compact? ? " " : "\n")

      if compact?
        "fragment #{@name} on #{@arguments[:on]} { #{all_fields} }"
      else
        "fragment #{@name} on #{@arguments[:on]} {\n#{all_fields}\n}"
      end
    end

    def format_arguments
      return "" if @arguments.empty?

      args = @arguments.map do |key, value|
        # Convert Ruby snake_case to GraphQL camelCase
        graphql_key = key.to_s.camelize(:lower)

        # Format value based on type
        formatted_value = case value
                          when String
                            # Check if it needs quotes (query parameter vs enum values)
                            # For metafields and most strings, add quotes
                            if %i[namespace key].include?(key.to_sym)
                              "\"#{value}\""
                            elsif key.to_sym == :query
                              "\"#{value}\""
                            else
                              value
                            end
                          when Symbol
                            value.to_s
                          else
                            value
                          end

        "#{graphql_key}: #{formatted_value}"
      end

      "(#{args.join(', ')})"
    end
  end

  # Represents the complete query tree structure
  class QueryTree
    def initialize
      @fragments = []
      @query_config = {}
    end

    # Class-level factory methods for building complete queries from loader configuration

    # Build a complete single-record query (find by ID)
    # @param graphql_type [String] The GraphQL type (e.g., "Customer")
    # @param loader_class [Class] The loader class
    # @param defined_attributes [Hash] Attribute definitions
    # @param model_class [Class] The model class
    # @param included_connections [Array] Connections to include
    # @return [String] Complete GraphQL query string
    def self.build_single_record_query(graphql_type:, loader_class:, defined_attributes:, model_class:, included_connections:)
      tree = new

      # Build and add fragment
      fragment_node = tree.build_fragment_node(
        graphql_type: graphql_type,
        loader_class: loader_class,
        defined_attributes: defined_attributes,
        model_class: model_class,
        included_connections: included_connections
      )
      tree.add_fragment(fragment_node)

      # Add query wrapper
      query_name = graphql_type.downcase
      fragment_name = "#{graphql_type}Fragment"
      tree.add_query(graphql_type, query_name, fragment_name)

      tree.to_s
    end

    # Build a complete collection query (root-level search/where)
    # @param graphql_type [String] The GraphQL type (e.g., "Customer")
    # @param loader_class [Class] The loader class
    # @param defined_attributes [Hash] Attribute definitions
    # @param model_class [Class] The model class
    # @param included_connections [Array] Connections to include
    # @param query_name [String] The connection field name (e.g., "customers")
    # @param variables [Hash] Query variables (first, query)
    # @param connection_type [Symbol] :nodes_only (default) or :connection
    # @return [String] Complete GraphQL query string
    def self.build_collection_query(graphql_type:, loader_class:, defined_attributes:, model_class:, included_connections:, query_name:, variables:, connection_type: :nodes_only)
      tree = new

      # Build and add fragment
      fragment_node = tree.build_fragment_node(
        graphql_type: graphql_type,
        loader_class: loader_class,
        defined_attributes: defined_attributes,
        model_class: model_class,
        included_connections: included_connections
      )
      tree.add_fragment(fragment_node)

      # Add collection query wrapper
      fragment_name = "#{graphql_type}Fragment"
      tree.add_collection_query(
        type: graphql_type,
        query_name: query_name,
        fragment_name: fragment_name,
        variables: variables,
        connection_type: connection_type
      )

      tree.to_s
    end

    # Build a complete connection query
    # @param graphql_type [String] The GraphQL type (e.g., "Order")
    # @param loader_class [Class] The loader class
    # @param defined_attributes [Hash] Attribute definitions
    # @param model_class [Class] The model class
    # @param included_connections [Array] Connections to include
    # @param query_name [String] The connection field name
    # @param variables [Hash] Query variables (first, sort_key, reverse, query)
    # @param parent_query [String] Optional parent query for nested connections
    # @param connection_type [Symbol] :connection or :singular
    # @return [String] Complete GraphQL query string
    def self.build_connection_query(graphql_type:, loader_class:, defined_attributes:, model_class:, included_connections:, query_name:, variables:, parent_query: nil, connection_type: :connection)
      tree = new

      # Build and add fragment
      fragment_node = tree.build_fragment_node(
        graphql_type: graphql_type,
        loader_class: loader_class,
        defined_attributes: defined_attributes,
        model_class: model_class,
        included_connections: included_connections
      )
      tree.add_fragment(fragment_node)

      # Add connection query wrapper
      fragment_name = "#{graphql_type}Fragment"
      tree.add_connection_query(
        query_name: query_name,
        fragment_name: fragment_name,
        variables: variables,
        parent_query: parent_query,
        connection_type: connection_type
      )

      tree.to_s
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
    # @return [QueryNode] The fragment node
    def self.build_fragment_node(graphql_type:, loader_class:, defined_attributes:, model_class:, included_connections:)
      tree = new
      tree.build_fragment_node(
        graphql_type: graphql_type,
        loader_class: loader_class,
        defined_attributes: defined_attributes,
        model_class: model_class,
        included_connections: included_connections
      )
    end

    # Normalize includes from various formats to a consistent hash structure
    # Class method for use without instantiation
    def self.normalize_includes(includes)
      normalized = {}

      includes.each do |inc|
        if inc.is_a?(Hash)
          inc.each do |key, value|
            key = key.to_sym
            normalized[key] ||= []

            values = value.is_a?(Array) ? value : [value]
            normalized[key].concat(values)
          end
        else
          key = inc.to_sym
          normalized[key] ||= []
        end
      end

      normalized
    end

    # Add a fragment to the tree
    def add_fragment(fragment_node)
      @fragments << fragment_node
    end

    # Add a query wrapper with variables for single record queries
    def add_query(type, query_name, fragment_name)
      @query_config = {
        type: :single_record,
        model_type: type,
        query_name: query_name,
        fragment_name: fragment_name
      }
    end

    # Add a collection query wrapper (for root-level connection queries with search)
    # @param type [String] The model type (e.g., "Customer")
    # @param query_name [String] The pluralized query name (e.g., "customers")
    # @param fragment_name [String] The fragment name to reference
    # @param variables [Hash] Query variables (e.g., { query: String, first: Int })
    # @param connection_type [Symbol] :connection (uses edges/nodes) or :nodes_only (direct nodes access)
    def add_collection_query(type:, query_name:, fragment_name:, variables: {}, connection_type: :nodes_only)
      @query_config = {
        type: :collection,
        model_type: type,
        query_name: query_name,
        fragment_name: fragment_name,
        variables: variables,
        connection_type: connection_type
      }
    end

    # Add a connection query (for root-level or nested connections)
    # @param query_name [String] The connection field name
    # @param fragment_name [String] The fragment name to reference
    # @param variables [Hash] Query variables
    # @param parent_query [String] Optional parent query (e.g., "customer(id: $id)")
    # @param connection_type [Symbol] :connection or :singular
    def add_connection_query(query_name:, fragment_name:, variables: {}, parent_query: nil, connection_type: :connection)
      @query_config = {
        type: :connection,
        query_name: query_name,
        fragment_name: fragment_name,
        variables: variables,
        parent_query: parent_query,
        connection_type: connection_type
      }
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

    # Normalize includes from various formats to a consistent hash structure
    # Delegates to class method for consistency
    def normalize_includes(includes)
      self.class.normalize_includes(includes)
    end

    # Build a fragment node
    def build_fragment(name:, graphql_type:)
      QueryNode.new(
        name: name,
        arguments: { on: graphql_type },
        node_type: :fragment
      )
    end

    # Convert the entire tree to a GraphQL string
    def to_s
      compact = ActiveShopifyGraphQL.configuration.compact_queries

      case @query_config[:type]
      when :single_record
        build_single_record_query(compact)
      when :collection
        build_collection_query(compact)
      when :connection
        build_connection_query(compact)
      else
        ""
      end
    end

    private

    def build_single_record_query(compact)
      fragments_string = @fragments.map(&:to_s).join(compact ? " " : "\n\n")
      type = @query_config[:model_type]
      query_name = @query_config[:query_name]
      fragment_name = @query_config[:fragment_name]

      if compact
        "#{fragments_string} query get#{type}($id: ID!) { #{query_name}(id: $id) { ...#{fragment_name} } }"
      else
        "#{fragments_string}\n\nquery get#{type}($id: ID!) {\n  #{query_name}(id: $id) {\n    ...#{fragment_name}\n  }\n}\n"
      end
    end

    def build_collection_query(compact)
      fragments_string = @fragments.map(&:to_s).join(compact ? " " : "\n\n")
      type = @query_config[:model_type]
      query_name = @query_config[:query_name]
      fragment_name = @query_config[:fragment_name]
      variables = @query_config[:variables] || {}
      connection_type = @query_config[:connection_type] || :nodes_only

      # Use inline values for all parameters (no GraphQL variables)
      # Filter out nil values
      field_params = build_field_parameters(variables.reject { |_k, v| v.nil? })
      field_signature = field_params.empty? ? "" : "(#{field_params.join(', ')})"

      # Build the query body based on connection type
      if connection_type == :nodes_only
        if compact
          "#{fragments_string} query get#{type.pluralize} { #{query_name}#{field_signature} { nodes { ...#{fragment_name} } } }"
        else
          "#{fragments_string}\nquery get#{type.pluralize} {\n  #{query_name}#{field_signature} {\n    nodes {\n      ...#{fragment_name}\n    }\n  }\n}\n"
        end
      elsif compact
        # Standard connection with edges/nodes
        "#{fragments_string} query get#{type.pluralize} { #{query_name}#{field_signature} { edges { node { ...#{fragment_name} } } } }"
      else
        "#{fragments_string}\nquery get#{type.pluralize} {\n  #{query_name}#{field_signature} {\n    edges {\n      node {\n        ...#{fragment_name}\n      }\n    }\n  }\n}\n"
      end
    end

    def build_connection_query(compact)
      fragments_string = @fragments.map(&:to_s).join(compact ? " " : "\n\n")
      query_name = @query_config[:query_name]
      fragment_name = @query_config[:fragment_name]
      variables = @query_config[:variables] || {}
      parent_query = @query_config[:parent_query]
      connection_type = @query_config[:connection_type] || :connection

      # Build variable declarations (only for parent ID if nested)
      var_declarations = parent_query ? ["$id: ID!"] : []
      query_signature = var_declarations.empty? ? "" : "(#{var_declarations.join(', ')})"

      # Build field parameters (inline values for connection args), filtering out nil values
      field_params = build_field_parameters(variables.reject { |_k, v| v.nil? })
      field_signature = field_params.empty? ? "" : "(#{field_params.join(', ')})"

      # Build the query body
      if parent_query
        # Nested query with parent
        build_nested_connection_query(compact, fragments_string, query_signature, parent_query, query_name, field_signature, fragment_name, connection_type)
      else
        # Root-level connection query
        build_root_connection_query(compact, fragments_string, query_signature, query_name, field_signature, fragment_name, connection_type)
      end
    end

    def build_nested_connection_query(compact, fragments_string, query_signature, parent_query, query_name, field_signature, fragment_name, connection_type)
      if connection_type == :singular
        if compact
          "#{fragments_string} query#{query_signature} { #{parent_query} { #{query_name}#{field_signature} { ...#{fragment_name} } } }"
        else
          "#{fragments_string}\nquery#{query_signature} {\n  #{parent_query} {\n    #{query_name}#{field_signature} {\n      ...#{fragment_name}\n    }\n  }\n}\n"
        end
      elsif compact
        "#{fragments_string} query#{query_signature} { #{parent_query} { #{query_name}#{field_signature} { edges { node { ...#{fragment_name} } } } } }"
      else
        "#{fragments_string}\nquery#{query_signature} {\n  #{parent_query} {\n    #{query_name}#{field_signature} {\n      edges {\n        node {\n          ...#{fragment_name}\n        }\n      }\n    }\n  }\n}\n"
      end
    end

    def build_root_connection_query(compact, fragments_string, query_signature, query_name, field_signature, fragment_name, connection_type)
      if connection_type == :singular
        if compact
          "#{fragments_string} query#{query_signature} { #{query_name}#{field_signature} { ...#{fragment_name} } }"
        else
          "#{fragments_string}\nquery#{query_signature} {\n  #{query_name}#{field_signature} {\n    ...#{fragment_name}\n  }\n}\n"
        end
      elsif connection_type == :nodes_only
        # Use nodes instead of edges/node
        if compact
          "#{fragments_string} query#{query_signature} { #{query_name}#{field_signature} { nodes { ...#{fragment_name} } } }"
        else
          "#{fragments_string}\nquery#{query_signature} {\n  #{query_name}#{field_signature} {\n    nodes {\n      ...#{fragment_name}\n    }\n  }\n}\n"
        end
      elsif compact
        "#{fragments_string} query#{query_signature} { #{query_name}#{field_signature} { edges { node { ...#{fragment_name} } } } }"
      else
        "#{fragments_string}\nquery#{query_signature} {\n  #{query_name}#{field_signature} {\n    edges {\n      node {\n        ...#{fragment_name}\n      }\n    }\n  }\n}\n"
      end
    end

    def build_field_parameters(variables)
      variables.map do |key, value|
        graphql_key = key.to_s.camelize(:lower)
        formatted_value = format_inline_value(key, value)
        "#{graphql_key}: #{formatted_value}"
      end
    end

    def format_inline_value(key, value)
      case value
      when Integer
        value.to_s
      when TrueClass, FalseClass
        value.to_s
      when String
        # The 'query' parameter needs quoted strings for search syntax
        if key.to_sym == :query
          "\"#{value}\""
        else
          # Other string values (like enum sort keys) don't need quotes
          value
        end
      else
        value.to_s
      end
    end
  end
end
