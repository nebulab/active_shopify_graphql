# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Response
    # Represents a page of results from a paginated GraphQL query.
    # Lazily builds model instances from attribute hashes on access.
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

      attr_reader :page_info, :query_scope

      # Initialize a paginated result.
      # Supports two modes:
      # 1. Lazy building: Pass attributes + model_class, records are built on first access
      # 2. Pre-built: Pass records directly (attributes/model_class can be nil)
      #
      # @param attributes [Array<Hash>, nil] Attribute hashes to build models from
      # @param model_class [Class, nil] The model class to instantiate
      # @param page_info [PageInfo] Pagination metadata
      # @param query_scope [Object] The relation/scope for fetching next/previous pages
      # @param records [Array, nil] Pre-built records (skips lazy building if provided)
      def initialize(page_info:, query_scope:, attributes: nil, model_class: nil, records: nil)
        @attributes = attributes || []
        @model_class = model_class
        @page_info = page_info
        @query_scope = query_scope
        @records = records # nil triggers lazy build, or stores pre-built records
      end

      # Get the records for this page (builds instances on first access if not pre-built)
      def records
        @records ||= build_records
      end

      # Iterate over records in this page
      def each(&block)
        records.each(&block)
      end

      # Access records by index
      def [](index)
        records[index]
      end

      # Number of records in this page
      def size
        @records ? @records.size : @attributes.size
      end
      alias length size

      # Check if this page has records
      def empty?
        @records ? @records.empty? : @attributes.empty?
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

      # First record(s) in this page
      # @param count [Integer, nil] If given, returns first n records as array
      # @return [Object, Array, nil] First record or array of first n records
      def first(count = nil)
        count ? records.first(count) : records.first
      end

      # Last record(s) in this page
      # @param count [Integer, nil] If given, returns last n records as array
      # @return [Object, Array, nil] Last record or array of last n records
      def last(count = nil)
        count ? records.last(count) : records.last
      end

      # Convert to array (useful for compatibility)
      def to_a
        records.dup
      end

      # Return all records across all pages
      # Warning: This will make multiple API calls if there are many pages
      # @return [Array] All records from all pages
      def all_records
        all = records.dup
        current = self

        while current.has_next_page?
          current = current.next_page
          all.concat(current.records)
        end

        all
      end

      private

      def build_records
        return [] if @model_class.nil?

        ModelBuilder.build_many(@model_class, @attributes)
      end
    end
  end
end
