# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Response
    # Represents a page of results from a paginated GraphQL query.
    # Provides methods to navigate between pages and access pagination metadata.
    #
    # @example Manual pagination
    #   page = ProductVariant.where(sku: "*").in_pages(of: 10)
    #   page.has_next_page? # => true
    #   next_page = page.next_page
    #
    # @example Iteration with block
    #   ProductVariant.where(sku: "*").in_pages(of: 10) do |page|
    #     page.each { |variant| process(variant) }
    #   end
    class PaginatedResult
      include Enumerable

      attr_reader :records, :page_info, :query_scope

      def initialize(records:, page_info:, query_scope:)
        @records = records
        @page_info = page_info
        @query_scope = query_scope
      end

      # Iterate over records in this page
      def each(&block)
        @records.each(&block)
      end

      # Access records by index
      def [](index)
        @records[index]
      end

      # Number of records in this page
      def size
        @records.size
      end
      alias length size

      # Check if this page has records
      def empty?
        @records.empty?
      end

      # Check if there is a next page
      def has_next_page?
        @page_info.has_next_page?
      end

      # Check if there is a previous page
      def has_previous_page?
        @page_info.has_previous_page?
      end

      # Cursor pointing to the start of this page
      def start_cursor
        @page_info.start_cursor
      end

      # Cursor pointing to the end of this page
      def end_cursor
        @page_info.end_cursor
      end

      # Fetch the next page of results
      # @return [PaginatedResult, nil] The next page or nil if no more pages
      def next_page
        return nil unless has_next_page?

        @query_scope.fetch_page(after: end_cursor)
      end

      # Fetch the previous page of results
      # @return [PaginatedResult, nil] The previous page or nil if no previous pages
      def previous_page
        return nil unless has_previous_page?

        @query_scope.fetch_page(before: start_cursor)
      end

      # Convert to array (useful for compatibility)
      def to_a
        @records.dup
      end

      # Return all records across all pages
      # Warning: This will make multiple API calls if there are many pages
      # @return [Array] All records from all pages
      def all_records
        all = @records.dup
        current = self

        while current.has_next_page?
          current = current.next_page
          all.concat(current.records)
        end

        all
      end
    end
  end
end
