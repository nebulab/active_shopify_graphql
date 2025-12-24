# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Metaobject
    # A paginated result for metaobject queries.
    # Similar to Response::PaginatedResult but specialized for metaobjects.
    #
    class MetaobjectPaginatedResult
      include Enumerable

      attr_reader :records, :page_info, :relation

      def initialize(records:, page_info:, relation:)
        @records = records
        @page_info = page_info
        @relation = relation
      end

      # Enumerable methods
      def each(&block)
        @records.each(&block)
      end

      def to_a
        @records
      end

      def size
        @records.size
      end
      alias length size

      def empty?
        @records.empty?
      end

      def first(count = nil)
        count ? @records.first(count) : @records.first
      end

      def last(count = nil)
        count ? @records.last(count) : @records.last
      end

      def [](index)
        @records[index]
      end

      # Pagination methods
      def has_next_page?
        @page_info.has_next_page?
      end

      def has_previous_page?
        @page_info.has_previous_page?
      end

      def next_page
        return nil unless has_next_page?

        @relation.fetch_page(after: @page_info.end_cursor)
      end

      def previous_page
        return nil unless has_previous_page?

        @relation.fetch_page(before: @page_info.start_cursor)
      end
    end
  end
end
