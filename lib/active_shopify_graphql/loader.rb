# frozen_string_literal: true

require 'active_model/type'
require 'global_id'
require_relative 'fragment'
require_relative 'response_mapper'
require_relative 'query'

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
    def initialize(model_class = nil, selected_attributes: nil, included_connections: nil, **)
      @model_class = model_class || self.class.model_class
      @selected_attributes = selected_attributes&.map(&:to_sym)
      @included_connections = included_connections || []
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
      Fragment.new(self).to_s
    end

    # Get or create a Query instance for this loader
    def query_builder
      @query_builder ||= Query.new(self)
    end

    # Delegate query building methods to Query class
    def query_name(model_type = nil)
      query_builder.query_name(model_type)
    end

    def fragment_name(model_type = nil)
      query_builder.fragment_name(model_type)
    end

    def graphql_query(model_type = nil)
      query_builder.graphql_query(model_type)
    end

    # Override this to map the GraphQL response to model attributes
    def map_response_to_attributes(response_data)
      # Use attributes-based mapping if attributes are defined, otherwise require manual implementation
      attrs = defined_attributes
      raise NotImplementedError, "#{self.class} must implement map_response_to_attributes" unless attrs.any?

      mapper = ResponseMapper.new(self)
      attributes = mapper.map_response_from_attributes(response_data)

      # If we have included connections, extract and cache them
      if @included_connections.any? && @model_class.respond_to?(:connections)
        connection_data = mapper.extract_connection_data(response_data)
        attributes[:_connection_cache] = connection_data unless connection_data.empty?
      end

      attributes
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
    # @return [String] The GraphQL query string
    def collection_graphql_query(model_type = nil)
      query_builder.collection_graphql_query(model_type)
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

    # Load records for a connection query
    # @param query_name [String] The connection field name (e.g., 'orders', 'addresses')
    # @param variables [Hash] The GraphQL variables (first, sort_key, reverse, query)
    # @param parent [Object] The parent object that owns this connection
    # @param connection_config [Hash] The connection configuration (optional, used to determine if nested)
    # @return [Array<Object>] Array of model instances
    def load_connection_records(query_name, variables, parent = nil, connection_config = nil)
      # Determine if this is a nested connection
      is_nested = connection_config&.dig(:nested) || parent.respond_to?(:id)

      if is_nested && parent
        query = nested_connection_graphql_query(query_name, variables, parent, connection_config)
        # Only the parent ID is passed as a variable for nested connections
        # Ensure we use the full GID format
        parent_id = extract_gid_from_parent(parent)
        query_variables = { id: parent_id }
      else
        query = connection_graphql_query(query_name, variables, connection_config)
        # No variables needed for root-level connections - all args are inline
        query_variables = {}
      end

      response_data = execute_graphql_query(query, **query_variables)

      return [] if response_data.nil?

      if is_nested && parent
        ResponseMapper.new(self).map_nested_connection_response_to_attributes(response_data, query_name, parent, connection_config)
      else
        ResponseMapper.new(self).map_connection_response_to_attributes(response_data, query_name, connection_config)
      end
    end

    private

    # Extract GraphQL Global ID (GID) from parent object using GlobalID library
    # Handles both full GIDs and numeric IDs, converting to proper Shopify GID format
    # @param parent [Object] The parent ActiveShopifyGraphQL model instance
    # @return [String] The GID in format "gid://shopify/ResourceType/123"
    def extract_gid_from_parent(parent)
      # Strategy 1: Check if parent has a dedicated 'gid' attribute
      return parent.gid if parent.respond_to?(:gid) && !parent.gid.nil?

      # Strategy 2: Get the id attribute
      id_value = parent.id

      # Try to parse as a GID first to check if it's already valid
      begin
        parsed_gid = URI::GID.parse(id_value)
        return id_value if parsed_gid # Already a valid GID
      rescue URI::InvalidURIError, URI::BadURIError, ArgumentError
        # Not a valid GID, proceed to build one
      end

      # Strategy 3: Build GID from numeric ID
      # Get the GraphQL type from the parent's class
      parent_type = if parent.class.respond_to?(:graphql_type_for_loader)
                      parent.class.graphql_type_for_loader(self.class)
                    elsif parent.class.respond_to?(:graphql_type)
                      parent.class.graphql_type
                    else
                      parent.class.name
                    end

      # Build the GID using URI::GID
      URI::GID.build(app: 'shopify', model_name: parent_type, model_id: id_value).to_s
    end

    def execute_graphql_query(query, **variables)
      if ActiveShopifyGraphQL.configuration.log_queries && ActiveShopifyGraphQL.configuration.logger
        ActiveShopifyGraphQL.configuration.logger.info("ActiveShopifyGraphQL Query:\n#{query}")
        ActiveShopifyGraphQL.configuration.logger.info("ActiveShopifyGraphQL Variables:\n#{variables}")
      end

      perform_graphql_query(query, **variables)
    end

    def perform_graphql_query(query, **variables)
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

    # Build GraphQL query for nested connection (field on parent object)
    def nested_connection_graphql_query(connection_field_name, variables, parent, connection_config = nil)
      query_builder.nested_connection_graphql_query(connection_field_name, variables, parent, connection_config)
    end

    # Build GraphQL query for connection with dynamic parameters
    def connection_graphql_query(query_name, variables, connection_config = nil)
      query_builder.connection_graphql_query(query_name, variables, connection_config)
    end
  end
end
