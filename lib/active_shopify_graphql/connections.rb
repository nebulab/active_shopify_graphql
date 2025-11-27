module ActiveShopifyGraphQL
  module Connections
    extend ActiveSupport::Concern

    included do
      class << self
        attr_accessor :defined_connections
      end

      self.defined_connections = {}
    end

    class_methods do
      def metafield(attribute_name, graphql_field: "metafield", target_class: "Shopify::GraphQL::Metafield")
        # Define the metafield accessor method
        define_method attribute_name do |namespace:, key:|
          cache_key = "#{attribute_name}_#{namespace}_#{key}"
          return @_metafield_cache[cache_key] if @_metafield_cache&.key?(cache_key)

          @_metafield_cache ||= {}

          # Build the metafield query
          metafield_query = self.class.send(:build_metafield_query, graphql_field, target_class)

          # Execute the query
          id_for_query = id.to_gid(self.class.model_name.name.demodulize)
          variables = { id: id_for_query, namespace: namespace, key: key }

          response = ActiveShopifyGraphQL.configuration.admin_api_client.execute(metafield_query, **variables)

          # Parse the response
          metafield_data = response.dig("data", self.class.finder_query_name, graphql_field)

          if metafield_data
            target_class_const = target_class.constantize
            @_metafield_cache[cache_key] = target_class_const.new(metafield_data)
          else
            @_metafield_cache[cache_key] = nil
          end
        end

        # Define a setter method for testing/mocking
        define_method "#{attribute_name}=" do |value|
          @_metafield_cache ||= {}
          # Use a generic cache key for setter (since we don't have namespace/key)
          @_metafield_cache["#{attribute_name}_test"] = value
        end
      end

      def connection(name, target_class: nil, arguments: {}, &block)
        target_class_name = target_class&.to_s || name.to_s.singularize.classify

        # Store connection metadata
        self.defined_connections[name] = {
          target_class: target_class_name,
          arguments: arguments,
          field_name: name.to_s.camelize(:lower)
        }

        # Define the connection method
        define_method name do |**query_args|
          return @_connection_cache[name][query_args] if @_connection_cache&.dig(name, query_args)

          @_connection_cache ||= {}
          @_connection_cache[name] ||= {}

          # Merge default arguments with provided ones
          merged_args = self.class.defined_connections[name][:arguments].merge(query_args)

          # Build the connection query
          connection_query = self.class.send(:build_connection_query, name, merged_args)

          # Execute the query
          id_for_query = id.to_gid(self.class.model_name.name.demodulize)
          variables = { id: id_for_query }.merge(merged_args)

          response = ActiveShopifyGraphQL.configuration.admin_api_client.execute(connection_query, **variables)

          # Parse the response
          connection_data = response.dig("data", self.class.finder_query_name, name.to_s.camelize(:lower))

          if connection_data && connection_data["edges"]
            target_class = target_class_name.constantize
            nodes = connection_data["edges"].map { |edge| target_class.new(edge["node"]) }

            # Return a connection result with nodes and page info
            @_connection_cache[name][query_args] = ConnectionResult.new(
              nodes: nodes,
              page_info: connection_data["pageInfo"],
              total_count: connection_data["totalCount"] # May be nil
            )
          else
            @_connection_cache[name][query_args] = ConnectionResult.new(nodes: [], page_info: {}, total_count: 0)
          end
        end

        # Define a setter method for testing/mocking
        define_method "#{name}=" do |value|
          @_connection_cache ||= {}
          @_connection_cache[name] ||= {}
          @_connection_cache[name][{}] = value
        end
      end

      private

      def build_metafield_query(graphql_field, target_class)
        target_class_const = target_class.constantize
        target_fragment = target_class_const.fragment

        <<~GRAPHQL
          #{target_fragment}
          query #{model_name.singular}Metafield($id: ID!, $namespace: String!, $key: String!) {
            #{@finder_query_name || model_name.singular}(id: $id) {
              #{graphql_field}(namespace: $namespace, key: $key) {
                ...shopify_#{target_class_const.model_name.element.downcase}Fragment
              }
            }
          }
        GRAPHQL
      end

      def build_connection_query(connection_name, arguments)
        connection_info = defined_connections[connection_name]
        target_class = connection_info[:target_class].constantize
        field_name = connection_info[:field_name]

        # Build arguments string for GraphQL
        args_string = build_arguments_string(arguments)

        # Get the target class fragment
        target_fragment = target_class.fragment

        <<~GRAPHQL
          #{target_fragment}
          query #{model_name.singular}Connection($id: ID!#{build_variables_string(arguments)}) {
            #{@finder_query_name || model_name.singular}(id: $id) {
              #{field_name}#{args_string} {
                edges {
                  node {
                    ...shopify_#{target_class.model_name.element.downcase}Fragment
                  }
                }
                pageInfo {
                  hasNextPage
                  hasPreviousPage
                  startCursor
                  endCursor
                }
              }
            }
          }
        GRAPHQL
      end

      def build_arguments_string(arguments)
        return "" if arguments.empty?

        args = arguments.map do |key, _value|
          "#{key}: $#{key}"
        end.join(", ")

        "(#{args})"
      end

      def build_variables_string(arguments)
        return "" if arguments.empty?

        variables = arguments.map do |key, _value|
          ", $#{key}: #{graphql_type_for_argument(key)}"
        end.join("")

        variables
      end

      def graphql_type_for_argument(key)
        case key.to_s
        when 'first', 'last' then 'Int'
        when 'after', 'before' then 'String'
        when 'sortKey' then 'OrderSortKeys' # Use proper enum type
        when 'reverse' then 'Boolean'
        when 'query' then 'String'
        when 'namespace' then 'String'
        else 'String' # Default fallback
        end
      end
    end

    # Result wrapper for connections
    class ConnectionResult
      attr_reader :nodes, :page_info, :total_count

      def initialize(nodes:, page_info:, total_count: nil)
        @nodes = nodes
        @page_info = page_info || {}
        @total_count = total_count
      end

      def each(&block)
        nodes.each(&block)
      end

      def map(&block)
        nodes.map(&block)
      end

      def size
        nodes.size
      end

      def count
        total_count || nodes.size
      end

      def empty?
        nodes.empty?
      end

      def first
        nodes.first
      end

      def last
        nodes.last
      end

      def has_next_page?
        page_info["hasNextPage"]
      end

      def has_previous_page?
        page_info["hasPreviousPage"]
      end

      def end_cursor
        page_info["endCursor"]
      end

      def start_cursor
        page_info["startCursor"]
      end
    end
  end
end
