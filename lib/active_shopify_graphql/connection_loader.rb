# frozen_string_literal: true

require 'global_id'

module ActiveShopifyGraphQL
  # Handles loading records for connections (associations)
  class ConnectionLoader
    attr_reader :connection_query, :loader_class

    def initialize(connection_query:, loader_class:, client_type:, response_mapper_factory:)
      @connection_query = connection_query
      @loader_class = loader_class
      @client_type = client_type
      @response_mapper_factory = response_mapper_factory
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
      query = @connection_query.nested_connection_graphql_query(query_name, variables, parent, connection_config)
      # Only the parent ID is passed as a variable for nested connections
      # Ensure we use the full GID format
      parent_id = extract_gid(parent)
      query_variables = { id: parent_id }

      executor = Executor.new(@client_type)
      response_data = executor.execute(query, **query_variables)

      return [] if response_data.nil?

      @response_mapper_factory.call.map_nested_connection_response_to_attributes(response_data, query_name, parent, connection_config)
    end

    # Load records for a root-level connection
    def load_root_connection(query_name, variables, connection_config)
      query = @connection_query.connection_graphql_query(query_name, variables, connection_config)
      # No variables needed for root-level connections - all args are inline
      query_variables = {}

      executor = Executor.new(@client_type)
      response_data = executor.execute(query, **query_variables)

      return [] if response_data.nil?

      @response_mapper_factory.call.map_connection_response_to_attributes(response_data, query_name, connection_config)
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

      # Strategy 3: Normalize to GID format
      # Get the GraphQL type from the parent's class
      parent_type = if parent.class.respond_to?(:graphql_type_for_loader)
                      parent.class.graphql_type_for_loader(@loader_class)
                    elsif parent.class.respond_to?(:graphql_type)
                      parent.class.graphql_type
                    else
                      parent.class.name
                    end

      GidHelper.normalize_gid(id_value, parent_type)
    end
  end
end
