# frozen_string_literal: true

require 'global_id'

module ActiveShopifyGraphQL
  # Handles loading records for connections (associations)
  class ConnectionLoader
    attr_reader :loader

    def initialize(loader)
      @loader = loader
    end

    # Load records for a connection query
    # @param query_name [String] The connection field name (e.g., 'orders', 'addresses')
    # @param variables [Hash] The GraphQL variables (first, sort_key, reverse, query)
    # @param parent [Object] The parent object that owns this connection
    # @param connection_config [Hash] The connection configuration (optional, used to determine if nested)
    # @return [Array<Object>] Array of model instances
    def load_records(query_name, variables, parent = nil, connection_config = nil)
      # Determine if this is a nested connection
      is_nested = connection_config&.dig(:nested) || parent.respond_to?(:id)

      if is_nested && parent
        load_nested_connection(query_name, variables, parent, connection_config)
      else
        load_root_connection(query_name, variables, connection_config)
      end
    end

    private

    # Load records for a nested connection (field on parent object)
    def load_nested_connection(query_name, variables, parent, connection_config)
      query = @loader.query_builder.nested_connection_graphql_query(query_name, variables, parent, connection_config)
      # Only the parent ID is passed as a variable for nested connections
      # Ensure we use the full GID format
      parent_id = extract_gid(parent)
      query_variables = { id: parent_id }

      executor = Executor.new(@loader)
      response_data = executor.execute(query, **query_variables)

      return [] if response_data.nil?

      ResponseMapper.new(@loader).map_nested_connection_response_to_attributes(response_data, query_name, parent, connection_config)
    end

    # Load records for a root-level connection
    def load_root_connection(query_name, variables, connection_config)
      query = @loader.query_builder.connection_graphql_query(query_name, variables, connection_config)
      # No variables needed for root-level connections - all args are inline
      query_variables = {}

      executor = Executor.new(@loader)
      response_data = executor.execute(query, **query_variables)

      return [] if response_data.nil?

      ResponseMapper.new(@loader).map_connection_response_to_attributes(response_data, query_name, connection_config)
    end

    # Extract GraphQL Global ID (GID) from parent object using GlobalID library
    # Handles both full GIDs and numeric IDs, converting to proper Shopify GID format
    # @param parent [Object] The parent ActiveShopifyGraphQL model instance
    # @return [String] The GID in format "gid://shopify/ResourceType/123"
    def extract_gid(parent)
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
                      parent.class.graphql_type_for_loader(@loader.class)
                    elsif parent.class.respond_to?(:graphql_type)
                      parent.class.graphql_type
                    else
                      parent.class.name
                    end

      # Build the GID using URI::GID
      URI::GID.build(app: 'shopify', model_name: parent_type, model_id: id_value).to_s
    end
  end
end
