# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Response
    # Handles mapping GraphQL responses to model attributes.
    # Refactored to use LoaderContext and unified mapping methods.
    class ResponseMapper
      attr_reader :context

      def initialize(context)
        @context = context
      end

      # Map GraphQL response to attributes using declared attribute metadata
      # @param response_data [Hash] The full GraphQL response
      # @param root_path [Array<String>] Path to the data root (e.g., ["data", "customer"])
      # @return [Hash] Mapped attributes
      def map_response(response_data, root_path: nil)
        root_path ||= ["data", @context.query_name]
        root_data = response_data.dig(*root_path)
        return {} unless root_data

        map_node_to_attributes(root_data)
      end

      # Map a single node's data to attributes (used for both root and nested)
      def map_node_to_attributes(node_data)
        return {} unless node_data

        result = {}
        @context.defined_attributes.each do |attr_name, config|
          value = extract_and_transform_value(node_data, config, attr_name)
          result[attr_name] = value
        end
        result
      end

      # Extract connection data from GraphQL response for eager loading
      def extract_connection_data(response_data, root_path: nil, parent_instance: nil)
        return {} if @context.included_connections.empty?

        root_path ||= ["data", @context.query_name]
        root_data = response_data.dig(*root_path)
        return {} unless root_data

        extract_connections_from_node(root_data, parent_instance)
      end

      # Extract connections from a node (reusable for nested connections)
      def extract_connections_from_node(node_data, parent_instance = nil)
        return {} if @context.included_connections.empty?

        connections = @context.connections
        return {} if connections.empty?

        normalized_includes = Query::QueryBuilder.normalize_includes(@context.included_connections)
        connection_cache = {}

        normalized_includes.each do |connection_name, nested_includes|
          connection_config = connections[connection_name]
          next unless connection_config

          records = extract_connection_records(node_data, connection_config, nested_includes, parent_instance: parent_instance)
          connection_cache[connection_name] = records if records
        end

        connection_cache
      end

      # Map nested connection response (when loading via parent query)
      def map_nested_connection_response(response_data, connection_field_name, parent, connection_config = nil)
        parent_type = parent.class.graphql_type_for_loader(@context.loader_class)
        parent_query_name = parent_type.camelize(:lower)
        connection_type = connection_config&.dig(:type) || :connection

        if connection_type == :singular
          node_data = response_data.dig("data", parent_query_name, connection_field_name)
          return nil unless node_data

          build_model_instance(node_data)
        else
          nodes = response_data.dig("data", parent_query_name, connection_field_name, "nodes")
          return [] unless nodes

          nodes.filter_map do |node_data|
            build_model_instance(node_data) if node_data
          end
        end
      end

      # Map root connection response
      def map_connection_response(response_data, query_name, connection_config = nil)
        connection_type = connection_config&.dig(:type) || :connection

        if connection_type == :singular
          node_data = response_data.dig("data", query_name)
          return nil unless node_data

          build_model_instance(node_data)
        else
          nodes = response_data.dig("data", query_name, "nodes")
          return [] unless nodes

          nodes.filter_map do |node_data|
            build_model_instance(node_data) if node_data
          end
        end
      end

      private

      def extract_and_transform_value(node_data, config, attr_name)
        path = config[:path]

        value = if config[:raw_graphql]
                  # For raw_graphql, the alias is the attr_name, then dig using path if nested
                  raw_data = node_data[attr_name.to_s]
                  if path.include?('.')
                    # Path is relative to the aliased root
                    path_parts = path.split('.')[1..] # Skip the first part (attr_name itself)
                    path_parts.any? ? raw_data&.dig(*path_parts) : raw_data
                  else
                    raw_data
                  end
                elsif path.include?('.')
                  # Nested path - dig using the full path
                  path_parts = path.split('.')
                  node_data.dig(*path_parts)
                else
                  # Simple path - use attr_name as key (matches the alias in the query)
                  node_data[attr_name.to_s]
                end

        value = apply_defaults_and_transforms(value, config)
        validate_null_constraint!(value, config, attr_name)
        coerce_value(value, config[:type])
      end

      def apply_defaults_and_transforms(value, config)
        if value.nil?
          return config[:default] unless config[:default].nil?

          return config[:transform]&.call(value)
        end

        config[:transform] ? config[:transform].call(value) : value
      end

      def validate_null_constraint!(value, config, attr_name)
        return unless !config[:null] && value.nil?

        raise ArgumentError, "Attribute '#{attr_name}' (GraphQL path: '#{config[:path]}') cannot be null but received nil"
      end

      def coerce_value(value, type)
        return nil if value.nil?
        return value if value.is_a?(Array) # Preserve arrays

        type_caster(type).cast(value)
      end

      def type_caster(type)
        case type
        when :string   then ActiveModel::Type::String.new
        when :integer  then ActiveModel::Type::Integer.new
        when :float    then ActiveModel::Type::Float.new
        when :boolean  then ActiveModel::Type::Boolean.new
        when :datetime then ActiveModel::Type::DateTime.new
        else ActiveModel::Type::Value.new
        end
      end

      def extract_connection_records(node_data, connection_config, nested_includes, parent_instance: nil)
        # Use original_name (Ruby attr name) as the response key since we alias connections
        response_key = connection_config[:original_name].to_s
        connection_type = connection_config[:type] || :connection
        target_class = connection_config[:class_name].constantize
        connection_name = connection_config[:original_name]

        if connection_type == :singular
          item_data = node_data[response_key]
          return nil unless item_data

          build_nested_model_instance(item_data, target_class, nested_includes,
                                      parent_instance: parent_instance,
                                      parent_connection_name: connection_name,
                                      connection_config: connection_config)
        else
          nodes = node_data.dig(response_key, "nodes")
          return nil unless nodes

          nodes.filter_map do |item_data|
            if item_data
              build_nested_model_instance(item_data, target_class, nested_includes,
                                          parent_instance: parent_instance,
                                          parent_connection_name: connection_name,
                                          connection_config: connection_config)
            end
          end
        end
      end

      def build_model_instance(node_data)
        return nil unless node_data

        attributes = map_node_to_attributes(node_data)
        @context.model_class.new(attributes)
      end

      def build_nested_model_instance(node_data, target_class, nested_includes, parent_instance: nil, parent_connection_name: nil, connection_config: nil) # rubocop:disable Lint/UnusedMethodArgument
        nested_context = @context.for_model(target_class, new_connections: nested_includes)
        nested_mapper = ResponseMapper.new(nested_context)

        attributes = nested_mapper.map_node_to_attributes(node_data)
        instance = target_class.new(attributes)

        # Populate inverse cache if inverse_of is specified
        if parent_instance && connection_config && connection_config[:inverse_of]
          inverse_name = connection_config[:inverse_of]
          instance.instance_variable_set(:@_connection_cache, {}) unless instance.instance_variable_get(:@_connection_cache)
          cache = instance.instance_variable_get(:@_connection_cache)

          # Check the type of the inverse connection to determine how to cache
          if target_class.respond_to?(:connections) && target_class.connections[inverse_name]
            inverse_type = target_class.connections[inverse_name][:type]
            cache[inverse_name] =
              if inverse_type == :singular
                parent_instance
              else
                # For collection inverses, wrap parent in an array
                [parent_instance]
              end
          end
        end

        # Handle nested connections recursively (instance becomes parent for its children)
        if nested_includes.any?
          nested_data = nested_mapper.extract_connections_from_node(node_data, instance)
          nested_data.each do |nested_name, nested_records|
            instance.send("#{nested_name}=", nested_records)
          end
        end

        instance
      end
    end
  end
end
