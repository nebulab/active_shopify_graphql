# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Query
    # A unified query builder that encapsulates all query configuration.
    # This class provides a consistent interface for chaining operations like
    # `where`, `find_by`, `includes`, `select`, `limit`, and pagination.
    #
    # Inspired by ActiveRecord::Relation, this class accumulates query state
    # and executes the query when records are accessed.
    #
    # @example Basic usage
    #   Customer.where(email: "john@example.com").first
    #   Customer.includes(:orders).find_by(id: 123)
    #   Customer.select(:id, :email).where(first_name: "John").limit(10).to_a
    #
    # @example Pagination
    #   Customer.where(country: "Canada").in_pages(of: 50) do |page|
    #     page.each { |customer| process(customer) }
    #   end
    class Relation
      include Enumerable

      DEFAULT_PER_PAGE = 250

      attr_reader :model_class, :included_connections, :conditions, :total_limit, :per_page

      def initialize(model_class, **options)
        @model_class = model_class
        @conditions = options[:conditions] || {}
        @included_connections = options[:included_connections] || []
        @selected_attributes = options[:selected_attributes]
        @total_limit = options[:total_limit]
        @per_page = [options[:per_page] || DEFAULT_PER_PAGE, ActiveShopifyGraphQL.configuration.max_objects_per_paginated_query].min
        @loader_class = options[:loader_class]
        @loader_extra_args = options[:loader_extra_args] || []
        @loaded = false
        @records = nil
      end

      # --------------------------------------------------------------------------
      # Chainable Query Methods
      # --------------------------------------------------------------------------

      # Add conditions to the query
      # @param conditions_or_first_condition [Hash, String] Conditions to filter by
      # @return [Relation] A new relation with conditions applied
      def where(conditions_or_first_condition = {}, *args, **options)
        new_conditions = build_conditions(conditions_or_first_condition, args, options)

        spawn(conditions: merge_conditions(@conditions, new_conditions))
      end

      # Find a single record by conditions
      # @param conditions [Hash] The conditions to match
      # @return [Object, nil] The first matching record or nil
      def find_by(conditions = {}, **options)
        merged = conditions.empty? ? options : conditions
        where(merged).first
      end

      # Find a single record by ID
      # @param id [String, Integer] The record ID
      # @return [Object] The model instance
      # @raise [ObjectNotFoundError] If the record is not found
      def find(id)
        gid = GidHelper.normalize_gid(id, @model_class.model_name.name.demodulize)

        result = if has_included_connections?
                   loader.load_with_instance(gid, @model_class)
                 else
                   attributes = loader.load_attributes(gid)
                   attributes.nil? ? nil : @model_class.new(attributes)
                 end

        raise ObjectNotFoundError, "Couldn't find #{@model_class.name} with id=#{id}" if result.nil?

        result
      end

      # Include connections for eager loading
      # @param connection_names [Array<Symbol>] Connection names to include
      # @return [Relation] A new relation with connections included
      def includes(*connection_names)
        validate_includes_connections!(connection_names)

        # Merge with existing and auto-eager-loaded connections
        auto_included = @model_class.connections
                                    .select { |_name, config| config[:eager_load] }
                                    .keys

        all_connections = (@included_connections + connection_names + auto_included).uniq

        spawn(included_connections: all_connections)
      end

      # Select specific attributes to optimize the query
      # @param attributes [Array<Symbol>] Attributes to select
      # @return [Relation] A new relation with selected attributes
      def select(*attributes)
        attrs = Array(attributes).flatten.map(&:to_sym)
        validate_select_attributes!(attrs)

        spawn(selected_attributes: attrs)
      end

      # Limit the total number of records returned
      # @param count [Integer] Maximum records to return
      # @return [Relation] A new relation with limit applied
      def limit(count)
        spawn(total_limit: count)
      end

      # --------------------------------------------------------------------------
      # Pagination Methods
      # --------------------------------------------------------------------------

      # Configure pagination and optionally iterate through pages
      # @param of [Integer] Records per page (default: 250, max: configurable)
      # @yield [PaginatedResult] Each page of results
      # @return [PaginatedResult, self] PaginatedResult if no block given
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
              trimmed_records = current_page.records.first(remaining)
              current_page = PaginatedResult.new(
                records: trimmed_records,
                page_info: PageInfo.new,
                query_scope: build_query_scope_for_pagination
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

      # --------------------------------------------------------------------------
      # Enumerable / Loading Methods
      # --------------------------------------------------------------------------

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

      # Get first record(s)
      # @param count [Integer, nil] Number of records to return
      # @return [Object, Array, nil] First record(s) or nil
      def first(count = nil)
        if count
          spawn(total_limit: count, per_page: [count, ActiveShopifyGraphQL.configuration.max_objects_per_paginated_query].min).to_a
        else
          spawn(total_limit: 1, per_page: 1).to_a.first
        end
      end

      # Check if any records exist
      # @return [Boolean]
      def exists?
        first(1).any?
      end

      # Check if no records exist
      # @return [Boolean]
      def empty?
        first(1).empty?
      end

      # Size/length of records (loads all pages)
      # @return [Integer]
      def size
        to_a.size
      end
      alias length size

      # Count records (loads all pages)
      # @return [Integer]
      def count
        to_a.count
      end

      # Array-like access
      def [](index)
        to_a[index]
      end

      # Map over records
      def map(&block)
        to_a.map(&block)
      end

      # Select/filter records (Array compatibility - differs from query select)
      def select_records(&block)
        to_a.select(&block)
      end

      # --------------------------------------------------------------------------
      # Inspection
      # --------------------------------------------------------------------------

      def inspect
        parts = [@model_class.name]
        parts << "includes(#{@included_connections.join(', ')})" if @included_connections.any?
        parts << "select(#{@selected_attributes.join(', ')})" if @selected_attributes
        parts << "where(#{@conditions.inspect})" unless @conditions.empty?
        parts << "limit(#{@total_limit})" if @total_limit
        "#<#{self.class.name} #{parts.join('.')}>"
      end

      # --------------------------------------------------------------------------
      # Internal State Accessors (for compatibility)
      # --------------------------------------------------------------------------

      def has_included_connections?
        @included_connections.any?
      end

      # --------------------------------------------------------------------------
      # Pagination Support
      # --------------------------------------------------------------------------

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
          query_scope: build_query_scope_for_pagination
        )
      end

      # Fetch the first page of results
      # @return [PaginatedResult]
      def fetch_first_page
        fetch_page
      end

      private

      # Create a new Relation with modified options
      def spawn(**changes)
        Query::Relation.new(
          @model_class,
          conditions: changes.fetch(:conditions, @conditions),
          included_connections: changes.fetch(:included_connections, @included_connections),
          selected_attributes: changes.fetch(:selected_attributes, @selected_attributes),
          total_limit: changes.fetch(:total_limit, @total_limit),
          per_page: changes.fetch(:per_page, @per_page),
          loader_class: changes.fetch(:loader_class, @loader_class),
          loader_extra_args: changes.fetch(:loader_extra_args, @loader_extra_args)
        )
      end

      def loader
        @loader ||= build_loader
      end

      def build_loader
        klass = @loader_class || @model_class.send(:default_loader_class)

        klass.new(
          @model_class,
          *@loader_extra_args,
          selected_attributes: @selected_attributes,
          included_connections: @included_connections
        )
      end

      def effective_per_page
        if @total_limit && @total_limit < @per_page
          @total_limit
        else
          @per_page
        end
      end

      # Build conditions from various input formats
      def build_conditions(conditions_or_first_condition, args, options)
        if conditions_or_first_condition.is_a?(String)
          binding_params = args.empty? && options.any? ? [options] : args
          binding_params.empty? ? conditions_or_first_condition : [conditions_or_first_condition, *binding_params]
        elsif conditions_or_first_condition.is_a?(Hash) && !conditions_or_first_condition.empty?
          conditions_or_first_condition
        else
          options
        end
      end

      # Merge existing conditions with new conditions
      def merge_conditions(existing, new_conditions)
        # If conditions are the same type, merge appropriately
        return new_conditions if existing.nil? || (existing.is_a?(Hash) && existing.empty?)

        # For string-based conditions or mixed types, keep the new ones
        # (In real GraphQL queries, we'd need smarter merging)
        new_conditions
      end

      # Build a Query::Scope for backward compatibility with PaginatedResult
      def build_query_scope_for_pagination
        Query::Scope.new(
          @model_class,
          conditions: @conditions,
          loader: loader,
          total_limit: @total_limit,
          per_page: @per_page
        )
      end

      def validate_includes_connections!(connection_names)
        return unless @model_class.respond_to?(:connections)

        connection_names.each do |name|
          if name.is_a?(Hash)
            # Nested includes: { line_items: :variant }
            name.each do |key, nested_value|
              unless @model_class.connections.key?(key.to_sym)
                available = @model_class.connections.keys
                raise ArgumentError, "Invalid connection for #{@model_class.name}: #{key}. " \
                                     "Available connections: #{available.join(', ')}"
              end

              # Recursively validate nested connections
              target_class = @model_class.connections[key.to_sym][:class_name].constantize
              next unless target_class.respond_to?(:connections)

              nested_names = nested_value.is_a?(Array) ? nested_value : [nested_value]
              nested_relation = Query::Relation.new(target_class)
              nested_relation.send(:validate_includes_connections!, nested_names)
            end
          else
            unless @model_class.connections.key?(name.to_sym)
              available = @model_class.connections.keys
              raise ArgumentError, "Invalid connection for #{@model_class.name}: #{name}. " \
                                   "Available connections: #{available.join(', ')}"
            end
          end
        end
      end

      def validate_select_attributes!(attributes)
        return if attributes.empty?

        available = available_select_attributes
        invalid = attributes - available
        return if invalid.empty?

        raise ArgumentError, "Invalid attributes for #{@model_class.name}: #{invalid.join(', ')}. " \
                             "Available attributes are: #{available.join(', ')}"
      end

      def available_select_attributes
        attrs = []

        # Get attributes from the model class
        loader_klass = @loader_class || @model_class.send(:default_loader_class)
        model_attrs = @model_class.attributes_for_loader(loader_klass)
        attrs.concat(model_attrs.keys) if model_attrs

        # Get attributes from the loader class
        loader_attrs = loader_klass.defined_attributes
        attrs.concat(loader_attrs.keys) if loader_attrs

        attrs.map(&:to_sym).uniq.sort
      end
    end
  end
end
