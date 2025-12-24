# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Metaobject
    # Loader for Metaobject queries.
    #
    # This loader handles the unique structure of metaobject queries:
    # - Single record: metaobject(id: "gid://...") { ... }
    # - Collection: metaobjects(type: "provider", first: 10) { nodes { ... } }
    #
    # Fields are accessed via the fields array pattern.
    #
    class MetaobjectLoader
      def initialize(model_class)
        @model_class = model_class
      end

      # Load a single metaobject by ID
      # @param id [String] The metaobject GID
      # @return [Hash, nil] The attribute hash or nil if not found
      def load_single(id)
        query = build_single_query
        response = execute_query(query, id: id)

        metaobject_data = response.dig("data", "metaobject")
        return nil unless metaobject_data

        map_metaobject_to_attributes(metaobject_data)
      end

      # Load a collection of metaobjects
      # @param conditions [Hash, String, Array] Query conditions
      # @param per_page [Integer] Number of records per page
      # @param after [String, nil] Cursor for forward pagination
      # @param before [String, nil] Cursor for backward pagination
      # @param relation [MetaobjectRelation] The relation for building results
      # @return [MetaobjectPaginatedResult] A paginated result
      def load_collection(conditions:, per_page:, relation:, after: nil, before: nil)
        query = build_collection_query(
          conditions: conditions,
          per_page: per_page,
          after: after,
          before: before
        )

        response = execute_query(query)
        map_paginated_response(response, relation)
      end

      private

      def build_single_query
        fields_fragment = build_fields_fragment
        <<~GRAPHQL
          query getMetaobject($id: ID!) {
            metaobject(id: $id) {
              id
              handle
              type
              displayName
              #{fields_fragment}
            }
          }
        GRAPHQL
      end

      def build_collection_query(conditions:, per_page:, after: nil, before: nil)
        metaobject_type = @model_class.metaobject_type
        fields_fragment = build_fields_fragment

        # Build pagination arguments
        pagination_args = []
        if before
          pagination_args << "last: #{per_page}"
          pagination_args << "before: \"#{before}\""
        else
          pagination_args << "first: #{per_page}"
          pagination_args << "after: \"#{after}\"" if after
        end

        # Build query argument if conditions present
        query_arg = build_query_argument(conditions)
        pagination_args << query_arg if query_arg

        args_string = pagination_args.join(", ")

        <<~GRAPHQL
          query getMetaobjects {
            metaobjects(type: "#{metaobject_type}", #{args_string}) {
              pageInfo {
                hasNextPage
                hasPreviousPage
                startCursor
                endCursor
              }
              nodes {
                id
                handle
                type
                displayName
                #{fields_fragment}
              }
            }
          }
        GRAPHQL
      end

      def build_fields_fragment
        # Request all defined fields from the metaobject
        attributes = @model_class.metaobject_attributes

        # If no specific fields defined, request all fields with both value types
        if attributes.empty?
          "fields { value jsonValue }"
        else
          # Build specific field requests for each attribute, only querying needed value field
          field_queries = attributes.map do |_attr_name, config|
            key = config[:key]
            aliased_key = key.gsub(/[^a-zA-Z0-9_]/, '_')
            # Only query the value field we actually need based on type
            value_field = config[:type] == :json ? 'jsonValue' : 'value'
            "#{aliased_key}: field(key: \"#{key}\") { #{value_field} }"
          end
          field_queries.join("\n")
        end
      end

      def build_query_argument(conditions)
        return nil if conditions.nil? || conditions.empty?

        search_query = SearchQuery.new(conditions)
        query_string = search_query.to_s
        return nil if query_string.empty?

        "query: \"#{query_string.gsub('"', '\\"')}\""
      end

      def execute_query(query, **variables)
        client = ActiveShopifyGraphQL.configuration.admin_api_client
        raise Error, "Admin API client not configured" unless client

        if ActiveShopifyGraphQL.configuration.log_queries && ActiveShopifyGraphQL.configuration.logger
          ActiveShopifyGraphQL.configuration.logger.info("Metaobject Query:\n#{query}")
          ActiveShopifyGraphQL.configuration.logger.info("Variables: #{variables}")
        end

        client.execute(query, **variables)
      end

      def map_metaobject_to_attributes(data)
        attributes = {
          id: data["id"],
          handle: data["handle"],
          type: data["type"],
          display_name: data["displayName"]
        }

        # Map metaobject fields to model attributes
        @model_class.metaobject_attributes.each do |attr_name, config|
          field_key = config[:key]
          aliased_key = field_key.gsub(/[^a-zA-Z0-9_]/, '_')

          # Try aliased field first, then fall back to fields array
          field_data = data[aliased_key] || find_field_in_array(data["fields"], field_key)
          value = extract_field_value(field_data, config)
          attributes[attr_name] = value
        end

        attributes
      end

      def find_field_in_array(fields, key)
        return nil unless fields.is_a?(Array)

        fields.find { |f| f["key"] == key }
      end

      def extract_field_value(field_data, config)
        return config[:default] unless field_data

        raw_value = if config[:type] == :json
                      field_data["jsonValue"]
                    else
                      field_data["value"]
                    end

        return config[:default] if raw_value.nil?

        coerced_value = coerce_value(raw_value, config[:type])
        config[:transform] ? config[:transform].call(coerced_value) : coerced_value
      end

      def coerce_value(value, type)
        case type
        when :integer
          value.to_i
        when :float
          value.to_f
        when :boolean
          [true, "true"].include?(value)
        when :datetime
          parse_datetime(value)
        when :json
          value # Already parsed by GraphQL
        else
          value.to_s
        end
      end

      def parse_datetime(value)
        Time.parse(value)
      rescue ArgumentError
        value
      end

      def map_node_to_record(node_data)
        attributes = map_metaobject_to_attributes(node_data)
        build_record(attributes)
      end

      def map_paginated_response(response_data, relation)
        connection_data = response_data.dig("data", "metaobjects")
        return empty_paginated_result(relation) unless connection_data

        page_info_data = connection_data["pageInfo"] || {}
        page_info = Response::PageInfo.new(page_info_data)

        nodes = connection_data["nodes"] || []
        records = nodes.map { |node_data| map_node_to_record(node_data) }

        MetaobjectPaginatedResult.new(
          records: records,
          page_info: page_info,
          relation: relation
        )
      end

      def build_record(attributes)
        instance = @model_class.new
        attributes.each do |key, value|
          setter = "#{key}="
          instance.public_send(setter, value) if instance.respond_to?(setter)
        end
        instance
      end

      def empty_paginated_result(relation)
        MetaobjectPaginatedResult.new(
          records: [],
          page_info: Response::PageInfo.new,
          relation: relation
        )
      end
    end
  end
end
