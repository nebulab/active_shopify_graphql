# frozen_string_literal: true

require 'active_model/type'

module ActiveShopifyGraphQL
  class Loader # rubocop:disable Metrics/ClassLength
    class << self
      # Set or get the GraphQL type for this loader
      def graphql_type(type = nil)
        return @graphql_type = type if type

        # Try to get GraphQL type from associated model class first
        return model_class.graphql_type_for_loader(self) if model_class.respond_to?(:graphql_type_for_loader)

        @graphql_type || raise(NotImplementedError, "#{self} must define graphql_type or have an associated model with graphql_type")
      end

      # Set or get the client type for this loader (:admin_api or :customer_account_api)
      def client_type(type = nil)
        return @client_type = type if type

        @client_type || :admin_api # Default to admin API
      end

      # Get the model class associated with this loader
      def model_class
        @model_class ||= infer_model_class
      end

      # Set the model class associated with this loader
      attr_writer :model_class

      # For backward compatibility - loaders can still define attributes directly
      def attribute(name, path: nil, type: :string, null: true, default: nil, transform: nil)
        @attributes ||= {}

        # Auto-infer GraphQL path for simple cases: display_name -> displayName
        path ||= infer_path(name)

        @attributes[name] = {
          path: path,
          type: type,
          null: null,
          default: default,
          transform: transform
        }
      end

      # For backward compatibility - loaders can still define metafield attributes directly
      def metafield_attribute(name, namespace:, key:, type: :string, null: true, default: nil, transform: nil)
        @attributes ||= {}
        @metafields ||= {}

        # Store metafield metadata for special handling
        @metafields[name] = {
          namespace: namespace,
          key: key,
          type: type
        }

        # Generate alias and path for metafield
        alias_name = "#{name}Metafield"
        value_field = type == :json ? 'jsonValue' : 'value'
        path = "#{alias_name}.#{value_field}"

        @attributes[name] = {
          path: path,
          type: type,
          null: null,
          default: default,
          transform: transform,
          is_metafield: true,
          metafield_alias: alias_name,
          metafield_namespace: namespace,
          metafield_key: key
        }
      end

      # Get all defined attributes (includes both direct and model attributes)
      def attributes
        defined_attributes
      end

      # Get all defined metafields (includes both direct and model metafields)
      def metafields
        defined_metafields
      end

      # Get attributes from the model class for this loader
      def defined_attributes
        return @attributes || {} unless model_class.respond_to?(:attributes_for_loader)

        # Get attributes defined in the model for this loader class
        model_attrs = model_class.attributes_for_loader(self)
        direct_attrs = @attributes || {}

        # Merge direct loader attributes with model attributes (model takes precedence)
        direct_attrs.merge(model_attrs)
      end

      # Get metafields from the model class
      def defined_metafields
        return @metafields || {} unless model_class.respond_to?(:metafields)

        model_class.metafields
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

      # Infer the model class from the GraphQL type
      # e.g., graphql_type "Customer" -> Customer
      def infer_model_class
        type = @graphql_type
        return nil unless type

        # Try to find the class based on GraphQL type
        begin
          Object.const_get(type)
        rescue NameError
          # If not found, return nil - the model class may not exist yet
          nil
        end
      end
    end

    # Initialize loader with optional model class and selected attributes
    def initialize(model_class = nil, selected_attributes: nil, **)
      @model_class = model_class || self.class.model_class
      @selected_attributes = selected_attributes&.map(&:to_sym)
    end

    # Get GraphQL type for this loader instance
    def graphql_type
      if @model_class.respond_to?(:graphql_type_for_loader)
        @model_class.graphql_type_for_loader(self.class)
      else
        self.class.graphql_type
      end
    end

    # Get defined attributes for this loader instance
    def defined_attributes
      attrs = if @model_class.respond_to?(:attributes_for_loader)
                @model_class.attributes_for_loader(self.class)
              else
                self.class.defined_attributes
              end

      # Filter by selected attributes if specified
      if @selected_attributes
        selected_attrs = {}
        (@selected_attributes + [:id]).uniq.each do |attr|
          selected_attrs[attr] = attrs[attr] if attrs.key?(attr)
        end
        selected_attrs
      else
        attrs
      end
    end

    # Get defined metafields for this loader instance
    def defined_metafields
      if @model_class.respond_to?(:metafields)
        @model_class.metafields
      else
        self.class.defined_metafields
      end
    end

    # Returns the complete GraphQL fragment built from class-level fragment fields
    def fragment
      build_fragment_from_fields
    end

    # Override this to define the query name (can accept model_type for customization)
    def query_name(model_type = nil)
      type = model_type || graphql_type
      type.downcase
    end

    # Override this to define the fragment name (can accept model_type for customization)
    def fragment_name(model_type = nil)
      type = model_type || graphql_type
      "#{type}Fragment"
    end

    # Builds the complete GraphQL query using the fragment
    def graphql_query(model_type = nil)
      type = model_type || graphql_type
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
      attrs = defined_attributes
      raise NotImplementedError, "#{self.class} must implement map_response_to_attributes" unless attrs.any?

      map_response_from_attributes(response_data)
    end

    # Executes the GraphQL query and returns the mapped attributes hash
    # The model instantiation is handled by the calling code
    def load_attributes(model_type_or_id, id = nil)
      # Support both old signature (model_type, id) and new signature (id)
      if id.nil?
        # New signature: load_attributes(id)
        actual_id = model_type_or_id
        type = graphql_type
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
      type = graphql_type
      fragment_name_value = fragment_name(type)

      # Use attributes-based fragment if attributes are defined, otherwise fall back to manual fragment
      fragment_fields = if defined_attributes.any?
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
      metafield_aliases = {}

      # Build a tree structure for nested paths
      defined_attributes.each_value do |config|
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
      regular_fields = build_graphql_from_tree(path_tree, 0)

      # Build metafield fragments
      metafield_fragments = metafield_aliases.map do |alias_name, config|
        "  #{alias_name}: metafield(namespace: \"#{config[:namespace]}\", key: \"#{config[:key]}\") {\n    #{config[:value_field]}\n  }"
      end

      # Combine regular fields and metafield fragments
      [regular_fields, metafield_fragments].flatten.compact.reject(&:empty?).join("\n")
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
      type = graphql_type
      query_name_value = query_name(type)
      root_data = response_data.dig("data", query_name_value)
      return {} unless root_data

      result = {}
      defined_attributes.each do |attr_name, config|
        path = config[:path]
        path_parts = path.split('.')

        # Use dig to safely extract the value
        value = root_data.dig(*path_parts)

        # Handle nil values with defaults or transforms
        if value.nil?
          # Use default value if provided (more efficient than transform for simple defaults)
          if !config[:default].nil?
            value = config[:default]
          elsif config[:transform]
            # Only call transform if no default is provided
            value = config[:transform].call(value)
          end
        elsif config[:transform]
          # Apply transform to non-nil values
          value = config[:transform].call(value)
        end

        # Validate null constraint after applying defaults/transforms
        raise ArgumentError, "Attribute '#{attr_name}' (GraphQL path: '#{path}') cannot be null but received nil" if !config[:null] && value.nil?

        # Apply type coercion
        result[attr_name] = value.nil? ? nil : coerce_value(value, config[:type], attr_name, path)
      end

      result
    end

    # Coerce a value to the specified type using ActiveSupport's type system
    def coerce_value(value, type, attr_name, path)
      # Automatically preserve arrays regardless of specified type
      return value if value.is_a?(Array)

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

    def execute_graphql_query(query, **variables)
      case self.class.client_type
      when :admin_api
        client = ActiveShopifyGraphQL.configuration.admin_api_client
        raise Error, "Admin API client not configured. Please configure it using ActiveShopifyGraphQL.configure" unless client

        client.execute(query, **variables)
      when :customer_account_api
        # Customer Account API implementation would go here
        # For now, raise an error since we'd need token handling
        raise NotImplementedError, "Customer Account API support needs token handling implementation"
      else
        raise ArgumentError, "Unknown client type: #{self.class.client_type}"
      end
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
