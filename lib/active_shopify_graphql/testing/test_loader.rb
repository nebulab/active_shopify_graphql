# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Testing
    # Loader subclass that reads from the in-memory Store instead of
    # executing GraphQL queries. Overrides the three main loading methods
    # and raises on any attempt to perform a real GraphQL query.
    class TestLoader < Loader
      # Load attributes for a single record by ID.
      #
      # @param id [String] The GID of the record
      # @return [Hash, nil] Filtered attribute hash with optional connection cache
      def load_attributes(id)
        record = Testing.store.find(@model_class, id)
        return nil unless record

        attrs = filter_to_model_attributes(record)

        populate_connection_cache(record, attrs) if @included_connections.any?

        attrs
      end

      # Load a paginated collection matching the given conditions.
      #
      # @return [Response::PaginatedResult]
      def load_paginated_collection(conditions:, per_page:, query_scope:, after: nil, before: nil, sort_key: nil, reverse: nil) # rubocop:disable Lint/UnusedMethodArgument
        all_records = Testing.store.where(@model_class, conditions)

        # Simple cursor-based pagination using array indices
        start_index = after ? after.to_i + 1 : 0
        start_index = [all_records.size - per_page, 0].max if before

        page_records = all_records[start_index, per_page] || []
        end_index = start_index + page_records.size - 1

        page_info = Response::PageInfo.new(
          "hasNextPage" => end_index < all_records.size - 1,
          "hasPreviousPage" => start_index.positive?,
          "startCursor" => start_index.to_s,
          "endCursor" => end_index.to_s
        )

        attributes_array = page_records.map do |record|
          attrs = filter_to_model_attributes(record)
          populate_connection_cache(record, attrs) if @included_connections.any?
          attrs
        end

        Response::PaginatedResult.new(
          attributes: attributes_array,
          model_class: @model_class,
          page_info: page_info,
          query_scope: query_scope
        )
      end

      # Load records for a connection (lazy-loaded or explicit).
      #
      # @return [Object, Array<Object>, nil] Built model instance(s)
      def load_connection_records(_query_name, _variables, parent = nil, connection_config = nil)
        return [] unless parent && connection_config

        connection_name = connection_config[:original_name]
        connection_data = Testing.store.connections_for(parent.class, parent.id, connection_name)

        return (connection_config[:type] == :singular ? nil : []) unless connection_data

        target_class = connection_config[:class_name].constantize
        singular = connection_config[:type] == :singular

        if singular
          data = connection_data.is_a?(Array) ? connection_data.first : connection_data
          return nil unless data

          attrs = filter_to_model_attributes(data, target_class)
          wire_inverse_of(parent, attrs, connection_config)
          ModelBuilder.build(target_class, attrs)
        else
          items = connection_data.is_a?(Array) ? connection_data : [connection_data]
          items.filter_map do |item|
            attrs = filter_to_model_attributes(item, target_class)
            wire_inverse_of(parent, attrs, connection_config)
            ModelBuilder.build(target_class, attrs)
          end
        end
      end

      # Should never be called — all data comes from the Store.
      def perform_graphql_query(_query, **_variables)
        raise "TestLoader should not execute GraphQL queries. " \
              "Ensure all test data is registered via ActiveShopifyGraphQL::Testing.register"
      end

      private

      # Filter a stored record hash down to only the declared model attributes,
      # then apply transforms and type coercion to match what the ResponseMapper
      # would produce from a real GraphQL response.
      def filter_to_model_attributes(record, model_class = @model_class)
        defined_attributes = model_class.attributes_for_loader(self.class)
        # Always include :id
        allowed_keys = (defined_attributes.keys + [:id]).uniq

        record.each_with_object({}) do |(key, value), attrs|
          next unless allowed_keys.include?(key)

          config = defined_attributes[key]
          if config
            value = apply_defaults_and_transforms(value, config)
            value = coerce_value(value, config[:type])
          end

          attrs[key] = value
        end
      end

      def apply_defaults_and_transforms(value, config)
        if value.nil?
          return config[:default] unless config[:default].nil?

          return config[:transform]&.call(value)
        end

        config[:transform] ? config[:transform].call(value) : value
      end

      def coerce_value(value, type)
        return nil if value.nil?
        return value if value.is_a?(Array)

        case type
        when :string   then ActiveModel::Type::String.new
        when :integer  then ActiveModel::Type::Integer.new
        when :float    then ActiveModel::Type::Float.new
        when :boolean  then ActiveModel::Type::Boolean.new
        when :datetime then ActiveModel::Type::DateTime.new
        else ActiveModel::Type::Value.new
        end.cast(value)
      end

      # Build connection cache from inline connection data in the stored record.
      def populate_connection_cache(record, attrs)
        normalized = Query::QueryBuilder.normalize_includes(@included_connections)

        cache = {}
        normalized.each do |connection_name, nested_includes|
          connection_config = @model_class.connections[connection_name]
          next unless connection_config

          connection_data = record[connection_name]
          next unless connection_data

          target_class = connection_config[:class_name].constantize
          singular = connection_config[:type] == :singular

          if singular
            data = connection_data.is_a?(Array) ? connection_data.first : connection_data
            if data
              child_attrs = filter_to_model_attributes(data, target_class)
              populate_nested_connections(data, child_attrs, target_class, nested_includes)
              cache[connection_name] = ModelBuilder.build(target_class, child_attrs)
            end
          else
            items = connection_data.is_a?(Array) ? connection_data : [connection_data]
            cache[connection_name] = items.filter_map do |item|
              child_attrs = filter_to_model_attributes(item, target_class)
              populate_nested_connections(item, child_attrs, target_class, nested_includes)
              ModelBuilder.build(target_class, child_attrs)
            end
          end
        end

        attrs[:_connection_cache] = cache unless cache.empty?
      end

      # Recursively populate nested connection caches for deeply included connections.
      def populate_nested_connections(record, attrs, model_class, nested_includes)
        return if nested_includes.nil? || nested_includes.empty?

        normalized = Query::QueryBuilder.normalize_includes(nested_includes)
        cache = {}

        normalized.each do |connection_name, deeper_includes|
          connection_config = model_class.connections[connection_name]
          next unless connection_config

          connection_data = record[connection_name]
          next unless connection_data

          target_class = connection_config[:class_name].constantize
          singular = connection_config[:type] == :singular

          if singular
            data = connection_data.is_a?(Array) ? connection_data.first : connection_data
            if data
              child_attrs = filter_to_model_attributes(data, target_class)
              populate_nested_connections(data, child_attrs, target_class, deeper_includes)
              cache[connection_name] = ModelBuilder.build(target_class, child_attrs)
            end
          else
            items = connection_data.is_a?(Array) ? connection_data : [connection_data]
            cache[connection_name] = items.filter_map do |item|
              child_attrs = filter_to_model_attributes(item, target_class)
              populate_nested_connections(item, child_attrs, target_class, deeper_includes)
              ModelBuilder.build(target_class, child_attrs)
            end
          end
        end

        attrs[:_connection_cache] = cache unless cache.empty?
      end

      # Wire inverse_of associations into the connection cache.
      def wire_inverse_of(parent, attributes, connection_config)
        return unless attributes.is_a?(Hash) && connection_config&.dig(:inverse_of)

        inverse_name = connection_config[:inverse_of]
        target_class = connection_config[:class_name].constantize
        return unless target_class.respond_to?(:connections) && target_class.connections[inverse_name]

        attributes[:_connection_cache] ||= {}
        inverse_type = target_class.connections[inverse_name][:type]
        attributes[:_connection_cache][inverse_name] =
          if inverse_type == :singular
            parent
          else
            [parent]
          end
      end
    end
  end
end
