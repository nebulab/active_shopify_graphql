# frozen_string_literal: true

require 'active_model/type'

module ActiveShopifyGraphQL
  class Loader # rubocop:disable Metrics/ClassLength
    class << self
      # Set or get the GraphQL type for this loader
      def graphql_type(type = nil)
        return @graphql_type = type if type

        @graphql_type || raise(NotImplementedError, "#{self} must define graphql_type")
      end

      # Define an attribute with GraphQL path mapping and type coercion
      # @param name [Symbol] The Ruby attribute name
      # @param path [String] The GraphQL field path (auto-inferred if not provided)
      # @param type [Symbol] The type for coercion (:string, :integer, :float, :boolean, :datetime)
      # @param null [Boolean] Whether the attribute can be null (default: true)
      # @param transform [Proc] Custom transform block for the value
      def attribute(name, path: nil, type: :string, null: true, transform: nil)
        @attributes ||= {}

        # Auto-infer GraphQL path for simple cases: display_name -> displayName
        path ||= infer_path(name)

        @attributes[name] = {
          path:,
          type:,
          null:,
          transform:,
        }
      end

      # Get all defined attributes
      def attributes
        @attributes || {}
      end

      # Set or get the GraphQL fragment fields for this loader
      # Example:
      #   fragment <<~GRAPHQL
      #     id
      #     displayName
      #     createdAt
      #     defaultEmailAddress {
      #       emailAddress
      #     }
      #     tags
      #   GRAPHQL
      def fragment(fields = nil)
        return @fragment_fields = fields if fields

        @fragment_fields || raise(NotImplementedError, "#{self} must define fragment")
      end

      private

      # Infer GraphQL path from Ruby attribute name
      # Only handles simple snake_case to camelCase conversion
      def infer_path(name)
        name.to_s.camelize(:lower)
      end
    end

    # Override this to define special behavior at loader initialization
    def initialize(**)
      # no-op
    end

    # Returns the complete GraphQL fragment built from class-level fragment fields
    def fragment
      build_fragment_from_fields
    end

    # Override this to define the query name (can accept model_type for customization)
    def query_name(model_type = nil)
      type = model_type || self.class.graphql_type
      type.downcase
    end

    # Override this to define the fragment name (can accept model_type for customization)
    def fragment_name(model_type = nil)
      type = model_type || self.class.graphql_type
      "#{type}Fragment"
    end

    # Builds the complete GraphQL query using the fragment
    def graphql_query(model_type = nil)
      type = model_type || self.class.graphql_type
      query_name_value = query_name(type)
      fragment_name_value = fragment_name(type)

      <<~GRAPHQL
        #{fragment}
        query get#{type}($id: ID!) {
          #{query_name_value}(id: $id) {
            ...#{fragment_name_value}
          }
        }
      GRAPHQL
    end

    # Override this to map the GraphQL response to model attributes
    def map_response_to_attributes(response_data)
      # Use attributes-based mapping if attributes are defined, otherwise require manual implementation
      raise NotImplementedError, "#{self.class} must implement map_response_to_attributes" unless self.class.attributes.any?

      map_response_from_attributes(response_data)
    end

    # Executes the GraphQL query and returns the mapped attributes hash
    # The model instantiation is handled by the calling code
    def load_attributes(model_type_or_id, id = nil)
      # Support both old signature (model_type, id) and new signature (id)
      if id.nil?
        # New signature: load_attributes(id)
        actual_id = model_type_or_id
        type = self.class.graphql_type
      else
        # Old signature: load_attributes(model_type, id)
        type = model_type_or_id
        actual_id = id
      end

      query = graphql_query(type)
      variables = { id: actual_id }

      response_data = execute_graphql_query(query, **variables)

      return nil if response_data.nil?

      map_response_to_attributes(response_data)
    end

    # Executes a collection query using Shopify's search syntax and returns an array of mapped attributes
    # @param conditions_or_model_type [Hash|String] The conditions to query or model type (for backwards compatibility)
    # @param conditions_or_limit [Hash|Integer] The conditions or limit (for backwards compatibility)
    # @param limit [Integer] The maximum number of records to return (default: 250, max: 250)
    # @return [Array<Hash>] Array of attribute hashes or empty array if none found
    def load_collection(conditions_or_model_type = {}, conditions_or_limit = {}, limit: 250)
      # Handle different method signatures for backwards compatibility
      if conditions_or_model_type.is_a?(String)
        # Old signature: load_collection(model_type, conditions = {}, limit: 250)
        type = conditions_or_model_type
        conditions = conditions_or_limit
        actual_limit = limit
      else
        # New signature: load_collection(conditions = {}, limit: 250)
        type = self.class.graphql_type
        conditions = conditions_or_model_type
        actual_limit = conditions_or_limit.is_a?(Integer) ? conditions_or_limit : limit
      end

      query_string = build_shopify_query_string(conditions)
      query = collection_graphql_query(type)
      variables = { query: query_string, first: actual_limit }

      # Use existing fragment and response mapping
      response = execute_graphql_query(query, **variables)

      # Check for search warnings/errors in extensions
      if response.dig("extensions", "search")
        warnings = response["extensions"]["search"].flat_map { |search| search["warnings"] || [] }
        unless warnings.empty?
          warning_messages = warnings.map { |w| "#{w['field']}: #{w['message']}" }
          raise ArgumentError, "Shopify query validation failed: #{warning_messages.join(', ')}"
        end
      end

      # Use the existing collection mapping method
      map_collection_response_to_attributes(response, type)
    end

    # Build Shopify query string from Ruby conditions

    # Builds the GraphQL query for collections
    # @param model_type [String] The model type (optional, uses class graphql_type if not provided)
    # @param _limit [Integer] The maximum number of records to return (unused, handled via variables)
    # @return [String] The GraphQL query string
    def collection_graphql_query(model_type = nil, _limit = 250)
      type = model_type || self.class.graphql_type
      query_name_value = query_name(type).pluralize
      fragment_name_value = fragment_name(type)

      <<~GRAPHQL
        #{fragment}
        query get#{type.pluralize}($query: String, $first: Int!) {
          #{query_name_value}(query: $query, first: $first) {
            nodes {
              ...#{fragment_name_value}
            }
          }
        }
      GRAPHQL
    end

    # Override this to map collection GraphQL responses to model attributes
    # @param response_data [Hash] The GraphQL response data
    # @param model_type [String] The model type (optional, uses class graphql_type if not provided)
    # @return [Array<Hash>] Array of attribute hashes
    def map_collection_response_to_attributes(response_data, model_type = nil)
      type = model_type || self.class.graphql_type
      query_name_value = query_name(type).pluralize
      nodes = response_data.dig("data", query_name_value, "nodes")

      return [] unless nodes&.any?

      nodes.map do |node_data|
        # Create a response structure similar to single record queries
        single_response = { "data" => { query_name(type) => node_data } }
        map_response_to_attributes(single_response)
      end.compact
    end

    private

    # Builds the complete fragment from class-level fragment fields or declared attributes
    def build_fragment_from_fields
      type = self.class.graphql_type
      fragment_name_value = fragment_name(type)

      # Use attributes-based fragment if attributes are defined, otherwise fall back to manual fragment
      fragment_fields = if self.class.attributes.any?
                          build_fragment_from_attributes
                        else
                          self.class.fragment
                        end

      <<~GRAPHQL
        fragment #{fragment_name_value} on #{type} {
          #{fragment_fields.strip}
        }
      GRAPHQL
    end

    # Build GraphQL fragment fields from declared attributes with path merging
    def build_fragment_from_attributes
      path_tree = {}

      # Build a tree structure for nested paths
      self.class.attributes.each do |_name, config|
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

      # Convert tree structure to GraphQL fragment syntax
      build_graphql_from_tree(path_tree, 0)
    end

    # Convert path tree to GraphQL syntax with proper indentation
    def build_graphql_from_tree(tree, indent_level)
      indent = "  " * indent_level

      tree.map do |key, value|
        if value == true
          # Leaf node - simple field
          "#{indent}#{key}"
        else
          # Branch node - nested selection
          nested_fields = build_graphql_from_tree(value, indent_level + 1)
          "#{indent}#{key} {\n#{nested_fields}\n#{indent}}"
        end
      end.join("\n")
    end

    # Map GraphQL response to attributes using declared attribute metadata
    def map_response_from_attributes(response_data)
      type = self.class.graphql_type
      query_name_value = query_name(type)
      root_data = response_data.dig("data", query_name_value)

      return {} unless root_data

      result = {}

      self.class.attributes.each do |attr_name, config|
        path = config[:path]
        path_parts = path.split('.')

        # Use dig to safely extract the value
        value = root_data.dig(*path_parts)

        # Validate null constraint
        raise ArgumentError, "Attribute '#{attr_name}' (GraphQL path: '#{path}') cannot be null but received nil" if !config[:null] && value.nil?

        # Apply type coercion if value is not nil
        if value.nil?
          result[attr_name] = nil
        else
          # Apply custom transform first, then type coercion
          value = config[:transform].call(value) if config[:transform]

          result[attr_name] = coerce_value(value, config[:type], attr_name, path)
        end
      end

      result
    end

    # Coerce a value to the specified type using ActiveSupport's type system
    def coerce_value(value, type, attr_name, path)
      type_caster = get_type_caster(type)
      type_caster.cast(value)
    rescue ArgumentError, TypeError => e
      raise ArgumentError, "Type conversion failed for attribute '#{attr_name}' (GraphQL path: '#{path}') to #{type}: #{e.message}"
    end

    # Get the appropriate ActiveModel::Type caster for the given type
    def get_type_caster(type)
      case type
      when :string
        ActiveModel::Type::String.new
      when :integer
        ActiveModel::Type::Integer.new
      when :float
        ActiveModel::Type::Float.new
      when :boolean
        ActiveModel::Type::Boolean.new
      when :datetime
        ActiveModel::Type::DateTime.new
      else
        # For unknown types, use a pass-through type that returns the value as-is
        ActiveModel::Type::Value.new
      end
    end

    def execute_graphql_query
      raise NotImplementedError, "#{self.class} must implement execute_graphql_query"
    end

    # Validates that all query attributes are supported by the model
    # @param conditions [Hash] The query conditions
    # @param model_type [String] The model type
    # @raise [ArgumentError] If any attribute is not valid for querying
    def validate_query_attributes!(conditions, model_type)
      return if conditions.empty?

      valid_attrs = valid_query_attributes(model_type)
      invalid_attrs = conditions.keys.map(&:to_s) - valid_attrs

      return unless invalid_attrs.any?

      raise ArgumentError, "Invalid query attributes for #{model_type}: #{invalid_attrs.join(', ')}. " \
                         "Valid attributes are: #{valid_attrs.join(', ')}"
    end

    # Builds a Shopify GraphQL query string from Ruby conditions
    # @param conditions [Hash] The query conditions
    # @return [String] The Shopify query string
    def build_shopify_query_string(conditions)
      return "" if conditions.empty?

      query_parts = conditions.map do |key, value|
        format_query_condition(key.to_s, value)
      end

      query_parts.join(" AND ")
    end

    # Formats a single query condition into Shopify's query syntax
    # @param key [String] The attribute name
    # @param value [Object] The attribute value
    # @return [String] The formatted query condition
    def format_query_condition(key, value)
      case value
      when String
        # Handle special string values and escape quotes
        if value.include?(" ") && !value.start_with?('"')
          # Multi-word values should be quoted
          "#{key}:\"#{value.gsub('"', '\\"')}\""
        else
          "#{key}:#{value}"
        end
      when Numeric
        "#{key}:#{value}"
      when true, false
        "#{key}:#{value}"
      when Hash
        # Handle range conditions like { created_at: { gte: '2024-01-01' } }
        range_parts = value.map do |operator, range_value|
          case operator.to_sym
          when :gt, :>
            "#{key}:>#{range_value}"
          when :gte, :>=
            "#{key}:>=#{range_value}"
          when :lt, :<
            "#{key}:<#{range_value}"
          when :lte, :<=
            "#{key}:<=#{range_value}"
          else
            raise ArgumentError, "Unsupported range operator: #{operator}"
          end
        end
        range_parts.join(" ")
      else
        "#{key}:#{value}"
      end
    end
  end
end
