# frozen_string_literal: true

require 'global_id'

module ActiveShopifyGraphQL
  module Connections
    # Handles loading records for GraphQL connections.
    # Refactored to use LoaderContext for cleaner parameter passing.
    class ConnectionLoader
      attr_reader :context

      def initialize(context, loader_instance:)
        @context = context
        @loader_instance = loader_instance
      end

      # Load records for a connection query
      # @param query_name [String] The connection field name (e.g., 'orders', 'addresses')
      # @param variables [Hash] The GraphQL variables (first, sort_key, reverse, query)
      # @param parent [Object] The parent object that owns this connection
      # @param connection_config [Hash] The connection configuration
      # @return [Array<Object>] Array of model instances
      def load_records(query_name, variables, parent = nil, connection_config = nil)
        is_nested = connection_config&.dig(:nested) || parent.respond_to?(:id)

        if is_nested && parent
          load_nested_connection(query_name, variables, parent, connection_config)
        else
          load_root_connection(query_name, variables, connection_config)
        end
      end

      private

      def load_nested_connection(query_name, variables, parent, connection_config)
        parent_type = parent.class.graphql_type_for_loader(@context.loader_class)
        parent_query_name = parent_type.camelize(:lower)
        connection_type = connection_config&.dig(:type) || :connection

        query = Query::Tree.build_connection_query(
          @context,
          query_name: query_name,
          variables: variables,
          parent_query: "#{parent_query_name}(id: $id)",
          connection_type: connection_type
        )

        parent_id = extract_gid(parent)
        response_data = @loader_instance.perform_graphql_query(query, id: parent_id)

        return [] if response_data.nil?

        mapper = Response::ResponseMapper.new(@context)
        mapper.map_nested_connection_response(response_data, query_name, parent, connection_config)
      end

      def load_root_connection(query_name, variables, connection_config)
        connection_type = connection_config&.dig(:type) || :connection

        query = Query::Tree.build_connection_query(
          @context,
          query_name: query_name,
          variables: variables,
          parent_query: nil,
          connection_type: connection_type
        )

        response_data = @loader_instance.perform_graphql_query(query)

        return [] if response_data.nil?

        mapper = Response::ResponseMapper.new(@context)
        mapper.map_connection_response(response_data, query_name, connection_config)
      end

      def extract_gid(parent)
        return parent.gid if parent.respond_to?(:gid) && !parent.gid.nil?

        id_value = parent.id
        parent_type = resolve_parent_type(parent)

        GidHelper.normalize_gid(id_value, parent_type)
      end

      def resolve_parent_type(parent)
        klass = parent.class

        if klass.respond_to?(:graphql_type_for_loader)
          klass.graphql_type_for_loader(@context.loader_class)
        elsif klass.respond_to?(:graphql_type)
          klass.graphql_type
        else
          klass.name
        end
      end
    end
  end
end
