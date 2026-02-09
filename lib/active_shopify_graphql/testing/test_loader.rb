# frozen_string_literal: true

require "base64"

module ActiveShopifyGraphQL
  module Testing
    # A test-specific loader that reads from the TestRegistry instead of
    # making network requests. This enables testing of code that uses
    # ActiveShopifyGraphQL models without hitting real GraphQL APIs.
    #
    # The TestLoader intercepts all query methods and returns data from
    # the registry, building responses that match the structure expected
    # by the ResponseMapper.
    #
    # @example Usage in tests
    #   ActiveShopifyGraphQL::Testing.enable!
    #   create_graphql_record(Customer, id: 123, email: "test@example.com")
    #   customer = Customer.find(123)
    #   customer.email # => "test@example.com"
    class TestLoader < Loader
      class << self
        # Track which loader was originally requested (for assertion purposes)
        attr_accessor :last_requested_loader_class
      end

      def initialize(model_class, selected_attributes: nil, included_connections: nil, original_loader_class: nil, **)
        super(model_class, selected_attributes: selected_attributes, included_connections: included_connections)
        @original_loader_class = original_loader_class
        self.class.last_requested_loader_class = original_loader_class
      end

      # Load attributes for a single record by GID
      # @param id [String] The GID of the record
      # @return [Hash, nil] The attribute hash or nil if not found
      def load_attributes(id)
        gid = GidHelper.normalize_gid(id, resolve_graphql_type)
        record = TestRegistry.find_by_gid(gid)
        return nil unless record

        build_attributes_from_record(record)
      end

      # Load a paginated collection with optional filtering
      # @param conditions [Hash] Filter conditions
      # @param per_page [Integer] Records per page
      # @param after [String, nil] Cursor for forward pagination
      # @param before [String, nil] Cursor for backward pagination
      # @param sort_key [String, nil] Sort field
      # @param reverse [Boolean, nil] Reverse sort order
      # @param query_scope [Query::Scope] The query scope
      # @return [Response::PaginatedResult] Paginated result
      def load_paginated_collection(conditions:, per_page:, query_scope:, after: nil, before: nil, sort_key: nil, reverse: nil)
        # Parse conditions - only support hash conditions for now
        parsed_conditions = parse_conditions(conditions)

        # Get matching records from registry
        all_records = TestRegistry.filter(@model_class, parsed_conditions)

        # Apply sorting if specified
        all_records = apply_sorting(all_records, sort_key, reverse)

        # Apply pagination
        paginated_records, page_info = apply_pagination(all_records, per_page: per_page, after: after, before: before)

        # Build attributes for each record
        attributes_array = paginated_records.map { |record| build_attributes_from_record(record) }

        Response::PaginatedResult.new(
          attributes: attributes_array,
          model_class: @model_class,
          page_info: page_info,
          query_scope: query_scope
        )
      end

      # Override perform_graphql_query to prevent accidental network calls
      def perform_graphql_query(_query, **_variables)
        raise NotImplementedError,
              "TestLoader does not perform network requests. " \
              "Use create_graphql_record to populate the test registry."
      end

      private

      def build_attributes_from_record(record)
        # Remove internal metadata, keep only real attributes
        attrs = record.reject { |k, _| k.to_s.start_with?('_') }

        # Filter to selected attributes if specified
        attrs = attrs.select { |k, _| @selected_attributes.include?(k.to_sym) || k.to_sym == :id } if @selected_attributes

        attrs
      end

      def parse_conditions(conditions)
        case conditions
        when Hash
          conditions
        when nil, ""
          {}
        else
          # For now, we only support hash conditions
          # String conditions would require parsing the SearchQuery format
          raise ArgumentError,
                "TestLoader only supports hash conditions. " \
                "Got: #{conditions.class}. Use where(field: value) syntax."
        end
      end

      def apply_sorting(records, sort_key, reverse)
        return records unless sort_key

        # Convert Shopify sort key format (e.g., "CREATED_AT") to attribute name
        attr_name = sort_key.to_s.downcase.to_sym

        sorted = records.sort_by do |record|
          value = record[attr_name]
          # Handle nil values by putting them at the end
          value.nil? ? [1, nil] : [0, value]
        end

        reverse ? sorted.reverse : sorted
      end

      def apply_pagination(records, per_page:, after:, before:)
        total_count = records.size

        # Find starting position based on cursor
        start_index = 0
        if after
          cursor_index = find_cursor_index(records, after)
          start_index = cursor_index + 1 if cursor_index
        elsif before
          cursor_index = find_cursor_index(records, before)
          start_index = [cursor_index - per_page, 0].max if cursor_index
        end

        # Slice the records
        end_index = [start_index + per_page, total_count].min
        paginated = records[start_index...end_index] || []

        # Build page info
        has_next = end_index < total_count
        has_previous = start_index > 0
        start_cursor = paginated.first ? encode_cursor(paginated.first[:_gid] || paginated.first[:id]) : nil
        end_cursor = paginated.last ? encode_cursor(paginated.last[:_gid] || paginated.last[:id]) : nil

        page_info = Response::PageInfo.new(
          "hasNextPage" => has_next,
          "hasPreviousPage" => has_previous,
          "startCursor" => start_cursor,
          "endCursor" => end_cursor
        )

        [paginated, page_info]
      end

      def find_cursor_index(records, cursor)
        decoded_gid = decode_cursor(cursor)
        records.index { |r| (r[:_gid] || r[:id]) == decoded_gid }
      end

      def encode_cursor(gid)
        Base64.strict_encode64(gid.to_s)
      end

      def decode_cursor(cursor)
        Base64.strict_decode64(cursor)
      rescue ArgumentError
        cursor # Return as-is if not base64 encoded
      end
    end
  end
end
