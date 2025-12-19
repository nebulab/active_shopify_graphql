# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Response
    # Holds pagination metadata returned from a Shopify GraphQL connection query.
    # Provides methods for navigating between pages.
    class PageInfo
      attr_reader :start_cursor, :end_cursor

      def initialize(data = {})
        @has_next_page = data["hasNextPage"] || false
        @has_previous_page = data["hasPreviousPage"] || false
        @start_cursor = data["startCursor"]
        @end_cursor = data["endCursor"]
      end

      def has_next_page?
        @has_next_page
      end

      def has_previous_page?
        @has_previous_page
      end

      # Check if this is an empty/null page info
      def empty?
        @start_cursor.nil? && @end_cursor.nil?
      end

      def to_h
        {
          has_next_page: @has_next_page,
          has_previous_page: @has_previous_page,
          start_cursor: @start_cursor,
          end_cursor: @end_cursor
        }
      end
    end
  end
end
