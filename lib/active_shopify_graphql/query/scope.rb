# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Query
    # A chainable query builder that accumulates query configuration
    # and executes the query when records are accessed.
    #
    # @example Basic usage
    #   ProductVariant.where(sku: "*").limit(100).to_a
    #
    # @example Pagination with block
    #   ProductVariant.where(sku: "*").in_pages(of: 50) do |page|
    #     process_batch(page)
    #   end
    #
    # @example Manual pagination
    #   page = ProductVariant.where(sku: "*").in_pages(of: 50)
    #   page.each { |record| process(record) }
    #   page = page.next_page while page.has_next_page?
    class Scope
      include Enumerable

      DEFAULT_PER_PAGE = 250
      MAX_PER_PAGE = 250

      attr_reader :model_class, :conditions, :total_limit, :per_page

      def initialize(model_class, conditions: {}, loader: nil, total_limit: nil, per_page: DEFAULT_PER_PAGE)
        @model_class = model_class
        @conditions = conditions
        @loader = loader
        @total_limit = total_limit
        @per_page = [per_page, MAX_PER_PAGE].min
        @loaded = false
        @records = nil
      end

      # Set a limit on total records to return
      # @param count [Integer] Maximum number of records to fetch across all pages
      # @return [Scope] A new scope with the limit applied
      def limit(count)
        dup_with(total_limit: count)
      end

      # Configure pagination and optionally iterate through pages
      # @param of [Integer] Number of records per page (default: 250, max: 250)
      # @yield [PaginatedResult] Each page of results
      # @return [PaginatedResult, self] Returns PaginatedResult if no block given
      def in_pages(of: DEFAULT_PER_PAGE, &block)
        page_size = [of, MAX_PER_PAGE].min
        scoped = dup_with(per_page: page_size)

        if block_given?
          scoped.each_page(&block)
          self
        else
          scoped.fetch_first_page
        end
      end

      # Iterate through all pages, yielding each page
      # @yield [PaginatedResult] Each page of results
      def each_page
        current_page = fetch_first_page
        records_yielded = 0

        loop do
          break if current_page.empty?

          # Apply total limit if set
          if @total_limit
            remaining = @total_limit - records_yielded
            break if remaining <= 0

            if current_page.size > remaining
              # Trim the page to fit the limit
              trimmed_records = current_page.records.first(remaining)
              current_page = Response::PaginatedResult.new(
                records: trimmed_records,
                page_info: Response::PageInfo.new, # Empty page info to stop pagination
                query_scope: self
              )
            end
          end

          yield current_page
          records_yielded += current_page.size

          break unless current_page.has_next_page?
          break if @total_limit && records_yielded >= @total_limit

          current_page = current_page.next_page
        end
      end

      # Iterate through all records across all pages
      # @yield [Object] Each record
      def each(&block)
        return to_enum(:each) unless block_given?

        each_page do |page|
          page.each(&block)
        end
      end

      # Load all records respecting total_limit
      # @return [Array] All records
      def to_a
        return @records if @loaded

        all_records = []
        each_page do |page|
          all_records.concat(page.to_a)
        end
        @records = all_records
        @loaded = true
        @records
      end
      alias load to_a

      # Get first record
      # @param count [Integer, nil] Number of records to return
      # @return [Object, Array, nil] First record(s) or nil
      def first(count = nil)
        if count
          scoped = dup_with(total_limit: count, per_page: [count, MAX_PER_PAGE].min)
          scoped.to_a
        else
          scoped = dup_with(total_limit: 1, per_page: 1)
          scoped.to_a.first
        end
      end

      # Check if any records exist
      # @return [Boolean]
      def exists?
        first(1).any?
      end

      # Check if no records exist (Array compatibility)
      # @return [Boolean]
      def empty?
        first(1).empty?
      end

      # Size/length of records (loads all pages, use with caution)
      # @return [Integer]
      def size
        to_a.size
      end
      alias length size

      # Count records (loads all pages, use with caution)
      # @return [Integer]
      def count
        to_a.count
      end

      # Array-like access
      def [](index)
        to_a[index]
      end

      # Map over records (Array compatibility)
      def map(&block)
        to_a.map(&block)
      end

      # Select/filter records (Array compatibility)
      def select_records(&block)
        to_a.select(&block)
      end

      # Fetch a specific page by cursor
      # @param after [String, nil] Cursor to fetch records after
      # @param before [String, nil] Cursor to fetch records before
      # @return [PaginatedResult]
      def fetch_page(after: nil, before: nil)
        loader.load_paginated_collection(
          conditions: @conditions,
          per_page: effective_per_page,
          after: after,
          before: before,
          query_scope: self
        )
      end

      # Fetch the first page of results
      # @return [PaginatedResult]
      def fetch_first_page
        fetch_page
      end

      private

      # Calculate effective per_page considering total_limit
      def effective_per_page
        if @total_limit && @total_limit < @per_page
          @total_limit
        else
          @per_page
        end
      end

      def loader
        @loader ||= @model_class.default_loader
      end

      def dup_with(**changes)
        Scope.new(
          @model_class,
          conditions: changes.fetch(:conditions, @conditions),
          loader: changes.fetch(:loader, @loader),
          total_limit: changes.fetch(:total_limit, @total_limit),
          per_page: changes.fetch(:per_page, @per_page)
        )
      end
    end
  end
end
