# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Metaobject
    # A specialized Relation for querying Metaobjects.
    #
    # Unlike regular models that use dynamic query names (e.g., customers, orders),
    # metaobjects always use the metaobjects(type: "xxx") query.
    #
    # @example Basic usage
    #   Provider.where(display_name: "Acme").first
    #   Provider.all.limit(10).to_a
    #
    class MetaobjectRelation
      include Enumerable

      DEFAULT_PER_PAGE = 250

      attr_reader :model_class, :conditions, :total_limit, :per_page

      def initialize(
        model_class,
        conditions: {},
        total_limit: nil,
        per_page: DEFAULT_PER_PAGE
      )
        @model_class = model_class
        @conditions = conditions
        @total_limit = total_limit
        @per_page = [per_page, ActiveShopifyGraphQL.configuration.max_objects_per_paginated_query].min
        @loaded = false
        @records = nil
      end

      # --------------------------------------------------------------------------
      # Chainable Query Methods
      # --------------------------------------------------------------------------

      # Add conditions to the query
      # @param conditions [Hash, String] Conditions to filter by
      # @return [MetaobjectRelation] A new relation with conditions applied
      def where(conditions_or_first_condition = {}, *args, **options)
        new_conditions = build_conditions(conditions_or_first_condition, args, options)

        if has_conditions? && !new_conditions.empty?
          raise ArgumentError, "Chaining multiple where clauses is not supported. " \
                               "Combine conditions in a single where call instead."
        end

        spawn(conditions: new_conditions)
      end

      # Find a single record by conditions
      # @param conditions [Hash] The conditions to match
      # @return [Object, nil] The first matching record or nil
      def find_by(conditions = {}, **options)
        merged = conditions.empty? ? options : conditions
        where(merged).first
      end

      # Find a single metaobject by ID
      # @param id [String] The metaobject GID
      # @return [Object] The model instance
      # @raise [ObjectNotFoundError] If the record is not found
      def find(id)
        gid = GidHelper.normalize_gid(id, "Metaobject")
        attributes = loader.load_single(gid)

        raise ObjectNotFoundError, "Couldn't find #{@model_class.name} with id=#{id}" if attributes.nil?

        build_instance(attributes)
      end

      # Limit the total number of records returned
      # @param count [Integer] Maximum records to return
      # @return [MetaobjectRelation] A new relation with limit applied
      def limit(count)
        spawn(total_limit: count)
      end

      # --------------------------------------------------------------------------
      # Enumerable / Loading Methods
      # --------------------------------------------------------------------------

      # Iterate through all records
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

      # Get first record(s)
      # @param count [Integer, nil] Number of records to return
      # @return [Object, Array, nil] First record(s) or nil
      def first(count = nil)
        if count
          spawn(total_limit: count, per_page: count).to_a
        else
          spawn(total_limit: 1, per_page: 1).to_a.first
        end
      end

      # --------------------------------------------------------------------------
      # Pagination Support
      # --------------------------------------------------------------------------

      # Configure pagination and optionally iterate through pages
      def in_pages(of: DEFAULT_PER_PAGE, &block)
        page_size = [of, ActiveShopifyGraphQL.configuration.max_objects_per_paginated_query].min
        scoped = spawn(per_page: page_size)

        if block_given?
          scoped.each_page(&block)
          self
        else
          scoped.fetch_first_page
        end
      end

      # Iterate through all pages
      def each_page
        current_page = fetch_first_page
        records_yielded = 0

        loop do
          break if current_page.empty?

          if @total_limit
            remaining = @total_limit - records_yielded
            break if remaining <= 0
          end

          yield current_page
          records_yielded += current_page.size

          break unless current_page.has_next_page?
          break if @total_limit && records_yielded >= @total_limit

          current_page = current_page.next_page
        end
      end

      # Fetch a specific page
      def fetch_page(after: nil, before: nil)
        loader.load_collection(
          conditions: @conditions,
          per_page: effective_per_page,
          after: after,
          before: before,
          relation: self
        )
      end

      def fetch_first_page
        fetch_page
      end

      # Size/length of records (loads all pages)
      def size
        to_a.size
      end
      alias length size

      def inspect
        parts = [@model_class.name]
        parts << "where(#{@conditions.inspect})" unless @conditions.empty?
        parts << "limit(#{@total_limit})" if @total_limit
        "#<#{self.class.name} #{parts.join('.')}>"
      end

      private

      def spawn(**changes)
        MetaobjectRelation.new(
          @model_class,
          conditions: changes.fetch(:conditions, @conditions),
          total_limit: changes.fetch(:total_limit, @total_limit),
          per_page: changes.fetch(:per_page, @per_page)
        )
      end

      def loader
        @loader ||= MetaobjectLoader.new(@model_class)
      end

      def has_conditions?
        case @conditions
        when Hash then @conditions.any?
        when String then !@conditions.empty?
        when Array then @conditions.any?
        else false
        end
      end

      def build_conditions(conditions_or_first_condition, args, options)
        case conditions_or_first_condition
        when String
          if args.any?
            [conditions_or_first_condition, *args]
          elsif options.any?
            [conditions_or_first_condition, options]
          else
            conditions_or_first_condition
          end
        when Hash
          conditions_or_first_condition.empty? ? options : conditions_or_first_condition
        else
          options
        end
      end

      def effective_per_page
        if @total_limit && @total_limit < @per_page
          @total_limit
        else
          @per_page
        end
      end

      def build_instance(attributes)
        instance = @model_class.new
        attributes.each do |key, value|
          setter = "#{key}="
          instance.public_send(setter, value) if instance.respond_to?(setter)
        end
        instance
      end
    end
  end
end
