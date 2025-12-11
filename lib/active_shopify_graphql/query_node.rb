# frozen_string_literal: true

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
    when :raw
      render_raw
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

    # Include alias if present
    field_name = @alias_name ? "#{@alias_name}: #{@name}" : @name

    if compact?
      "#{field_name}#{args_string} { edges { node { #{fields_string} } } }"
    else
      <<~GRAPHQL.strip
        #{field_name}#{args_string} {
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

    # Include alias if present
    field_name = @alias_name ? "#{@alias_name}: #{@name}" : @name

    if compact?
      "#{field_name}#{args_string} { #{fields_string} }"
    else
      "#{field_name}#{args_string} {\n#{nested_indent}#{fields_string}\n#{indent}}"
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

  def render_raw
    # Raw GraphQL string stored in arguments[:raw_graphql]
    @arguments[:raw_graphql]
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
