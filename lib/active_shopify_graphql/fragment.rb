# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Represents a GraphQL fragment for a model with its fields and connections
  class Fragment # rubocop:disable Metrics/ClassLength
    attr_reader :graphql_type, :loader_class, :defined_attributes, :model_class, :included_connections

    def initialize(graphql_type:, loader_class:, defined_attributes:, model_class:, included_connections:, fragment_name_proc:, fallback_fragment_proc: nil)
      @graphql_type = graphql_type
      @loader_class = loader_class
      @defined_attributes = defined_attributes
      @model_class = model_class
      @included_connections = included_connections
      @fragment_name_proc = fragment_name_proc
      @has_fallback = @defined_attributes.empty? && fallback_fragment_proc
      @fallback_fragment_proc = fallback_fragment_proc
    end

    # Returns the complete GraphQL fragment string
    def to_s
      fragment_name_value = @fragment_name_proc.call(@graphql_type)

      compact = ActiveShopifyGraphQL.configuration.compact_queries
      separator = compact ? " " : "\n"

      all_fields = [fields.strip, connection_fields].reject(&:empty?).join(separator)

      if compact
        "fragment #{fragment_name_value} on #{@graphql_type} { #{all_fields} }"
      else
        "fragment #{fragment_name_value} on #{@graphql_type} {\n#{all_fields}\n}"
      end
    end

    # Returns the fragment fields (attributes and metafields) as GraphQL string
    def fields
      # Use attributes-based fragment if attributes are defined, otherwise fall back to manual fragment
      if @defined_attributes.any?
        fields_from_attributes
      elsif @has_fallback
        @fallback_fragment_proc.call
      else
        raise NotImplementedError, "#{@loader_class} must define fragment or attributes"
      end
    end

    # Returns the connection fields as GraphQL string
    def connection_fields
      return "" if @included_connections.empty? || !@model_class.respond_to?(:connections)

      connections = @model_class.connections
      normalized_includes = normalize_includes(@included_connections)

      normalized_includes.map do |connection_name, nested_includes|
        connection_config = connections[connection_name]
        next unless connection_config

        # Get the target model class to determine its fragment
        target_class = connection_config[:class_name].constantize

        # Create a loader for the target model to get its fragment fields
        target_loader = @loader_class.new(target_class, included_connections: nested_includes)
        target_fragment = Fragment.new(
          graphql_type: target_loader.graphql_type,
          loader_class: target_loader.class,
          defined_attributes: target_loader.defined_attributes,
          model_class: target_loader.instance_variable_get(:@model_class),
          included_connections: target_loader.instance_variable_get(:@included_connections),
          fragment_name_proc: ->(type) { target_loader.fragment_name(type) },
          fallback_fragment_proc: -> { target_loader.class.fragment }
        )
        target_fragment_fields = if target_class.respond_to?(:attributes_for_loader) && target_class.attributes_for_loader(@loader_class).any?
                                   target_fragment.fields_from_attributes
                                 else
                                   # Fall back to basic fields if no attributes defined
                                   "id"
                                 end

        # Recursively build connection fragments for the target
        nested_connection_fragments = target_fragment.connection_fields

        # Combine attributes and nested connections
        compact = ActiveShopifyGraphQL.configuration.compact_queries
        separator = compact ? " " : "\n"
        full_target_fields = [target_fragment_fields, nested_connection_fragments].reject(&:empty?).join(separator)

        # Build connection fragment with GraphQL connection syntax
        query_name = connection_config[:query_name]
        connection_type = connection_config[:type] || :connection

        query_args = connection_config[:default_arguments] || {}

        # Passthrough all arguments with camelCase transformation
        args = query_args.map do |key, value|
          # Convert Ruby snake_case to GraphQL camelCase
          graphql_key = key.to_s.camelize(:lower)

          # Format value based on type and parameter name
          formatted_value = case value
                            when String
                              # The 'query' parameter needs quoted strings for search syntax
                              # Other string parameters (like sortKey enum values) don't need quotes
                              if key.to_sym == :query
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

        args_string = args.empty? ? "" : "(#{args.join(', ')})"

        if connection_type == :singular
          if compact
            "#{query_name}#{args_string} { #{full_target_fields} }"
          else
            <<~GRAPHQL.strip
              #{query_name}#{args_string} {
                #{full_target_fields}
              }
            GRAPHQL
          end
        elsif compact
          "#{query_name}#{args_string} { edges { node { #{full_target_fields} } } }"
        else
          <<~GRAPHQL.strip
            #{query_name}#{args_string} {
              edges {
                node {
                  #{full_target_fields}
                }
              }
            }
          GRAPHQL
        end
      end.compact.join(ActiveShopifyGraphQL.configuration.compact_queries ? " " : "\n")
    end

    # Build GraphQL fragment fields from declared attributes with path merging
    def fields_from_attributes
      path_tree = {}
      metafield_aliases = {}

      # Build a tree structure for nested paths
      @defined_attributes.each_value do |config|
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
          # Handle regular attributes
          path_parts = config[:path].split('.')
          current_level = path_tree

          path_parts.each_with_index do |part, index|
            if index == path_parts.length - 1
              # Leaf node - store as string
              current_level[part] = true
            else
              # Branch node - ensure it's a hash
              current_level[part] ||= {}
              current_level = current_level[part]
            end
          end
        end
      end

      # Build fragment from regular attributes
      regular_fields = build_graphql_from_tree(path_tree, 1)

      # Build metafield fragments
      metafield_fragments = metafield_aliases.map do |alias_name, config|
        "  #{alias_name}: metafield(namespace: \"#{config[:namespace]}\", key: \"#{config[:key]}\") {\n    #{config[:value_field]}\n  }"
      end

      # Combine regular fields and metafield fragments
      [regular_fields, metafield_fragments].flatten.compact.reject(&:empty?).join("\n")
    end

    # Normalize includes from various formats to a consistent hash structure
    def normalize_includes(includes)
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

    private

    # Convert path tree to GraphQL syntax with proper indentation
    def build_graphql_from_tree(tree, indent_level)
      compact = ActiveShopifyGraphQL.configuration.compact_queries
      indent = compact ? "" : "  " * indent_level
      separator = compact ? " " : "\n"

      tree.map do |key, value|
        if value == true
          # Leaf node - simple field
          "#{indent}#{key}"
        else
          # Branch node - nested selection
          nested_fields = build_graphql_from_tree(value, indent_level + 1)
          if compact
            "#{key} { #{nested_fields} }"
          else
            "#{indent}#{key} {\n#{nested_fields}\n#{indent}}"
          end
        end
      end.join(separator)
    end
  end
end
