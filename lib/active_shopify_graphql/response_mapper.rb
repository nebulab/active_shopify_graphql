# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Handles mapping GraphQL responses to model attributes
  class ResponseMapper
    attr_reader :graphql_type, :loader_class, :defined_attributes, :model_class, :included_connections

    def initialize(graphql_type:, loader_class:, defined_attributes:, model_class:, included_connections:, query_name_proc:)
      @graphql_type = graphql_type
      @loader_class = loader_class
      @defined_attributes = defined_attributes
      @model_class = model_class
      @included_connections = included_connections
      @query_name_proc = query_name_proc
    end

    # Map GraphQL response to attributes using declared attribute metadata
    def map_response_from_attributes(response_data)
      query_name_value = @query_name_proc.call(@graphql_type)
      root_data = response_data.dig("data", query_name_value)
      return {} unless root_data

      result = {}
      @defined_attributes.each do |attr_name, config|
        path = config[:path]
        path_parts = path.split('.')

        # Use dig to safely extract the value
        value = root_data.dig(*path_parts)

        # Handle nil values with defaults or transforms
        if value.nil?
          # Use default value if provided (more efficient than transform for simple defaults)
          if !config[:default].nil?
            value = config[:default]
          elsif config[:transform]
            # Only call transform if no default is provided
            value = config[:transform].call(value)
          end
        elsif config[:transform]
          # Apply transform to non-nil values
          value = config[:transform].call(value)
        end

        # Validate null constraint after applying defaults/transforms
        raise ArgumentError, "Attribute '#{attr_name}' (GraphQL path: '#{path}') cannot be null but received nil" if !config[:null] && value.nil?

        # Apply type coercion
        result[attr_name] = value.nil? ? nil : coerce_value(value, config[:type], attr_name, path)
      end

      result
    end

    # Coerce a value to the specified type using ActiveSupport's type system
    def coerce_value(value, type, attr_name, path)
      # Automatically preserve arrays regardless of specified type
      return value if value.is_a?(Array)

      type_caster = get_type_caster(type)
      type_caster.cast(value)
    rescue ArgumentError, TypeError => e
      raise ArgumentError, "Type conversion failed for attribute '#{attr_name}' (GraphQL path: '#{path}') to #{type}: #{e.message}"
    end

    # Get the appropriate ActiveModel::Type caster for the given type
    def get_type_caster(type)
      case type
      when :string
        ActiveModel::Type::String.new
      when :integer
        ActiveModel::Type::Integer.new
      when :float
        ActiveModel::Type::Float.new
      when :boolean
        ActiveModel::Type::Boolean.new
      when :datetime
        ActiveModel::Type::DateTime.new
      else
        # For unknown types, use a pass-through type that returns the value as-is
        ActiveModel::Type::Value.new
      end
    end

    # Extract connection data from GraphQL response for eager loading
    def extract_connection_data(response_data)
      return {} if @included_connections.empty? || !@model_class.respond_to?(:connections)

      query_name_value = @query_name_proc.call(@graphql_type)
      root_data = response_data.dig("data", query_name_value)
      return {} unless root_data

      extract_connection_data_from_node(root_data)
    end

    def extract_connection_data_from_node(node_data)
      return {} if @included_connections.empty? || !@model_class.respond_to?(:connections)

      connection_cache = {}
      connections = @model_class.connections
      # We just need Fragment for normalize_includes - create it directly
      fragment = Fragment.new(
        graphql_type: @graphql_type,
        loader_class: @loader_class,
        defined_attributes: @defined_attributes,
        model_class: @model_class,
        included_connections: @included_connections
      )
      normalized_includes = fragment.normalize_includes(@included_connections)

      normalized_includes.each do |connection_name, nested_includes|
        connection_config = connections[connection_name]
        next unless connection_config

        query_name = connection_config[:query_name]
        connection_type = connection_config[:type] || :connection
        target_class = connection_config[:class_name].constantize

        records = if connection_type == :singular
                    node_data_item = node_data[query_name]
                    next unless node_data_item

                    build_model_instance_from_node(node_data_item, target_class, nested_includes)
                  else
                    edges = node_data.dig(query_name, "edges")
                    next unless edges

                    edges.map do |edge|
                      node_data_item = edge["node"]
                      next if node_data_item.nil?

                      build_model_instance_from_node(node_data_item, target_class, nested_includes)
                    end.compact
                  end

        connection_cache[connection_name] = records
      end

      connection_cache
    end

    # Map nested connection response to model attributes
    def map_nested_connection_response_to_attributes(response_data, connection_field_name, parent, connection_config = nil)
      parent_type = parent.class.graphql_type_for_loader(@loader_class)
      parent_query_name = parent_type.downcase

      connection_type = connection_config&.dig(:type) || :connection

      if connection_type == :singular
        node_data = response_data.dig("data", parent_query_name, connection_field_name)
        return nil unless node_data

        build_model_instance_from_attributes(node_data)
      else
        edges = response_data.dig("data", parent_query_name, connection_field_name, "edges")
        return [] unless edges

        edges.map do |edge|
          node_data = edge["node"]
          next if node_data.nil?

          build_model_instance_from_attributes(node_data)
        end.compact
      end
    end

    # Map connection response to model attributes
    def map_connection_response_to_attributes(response_data, query_name, connection_config = nil)
      connection_type = connection_config&.dig(:type) || :connection

      if connection_type == :singular
        node_data = response_data.dig("data", query_name)
        return nil unless node_data

        build_model_instance_from_attributes(node_data)
      else
        edges = response_data.dig("data", query_name, "edges")
        return [] unless edges

        edges.map do |edge|
          node_data = edge["node"]
          next if node_data.nil?

          build_model_instance_from_attributes(node_data)
        end.compact
      end
    end

    private

    def build_model_instance_from_node(node_data_item, target_class, nested_includes)
      attributes = {}
      if target_class.respond_to?(:attributes_for_loader)
        target_attributes = target_class.attributes_for_loader(@loader_class)
        target_attributes.each do |attr_name, config|
          path = config[:path]
          path_parts = path.split('.')
          value = node_data_item.dig(*path_parts)
          value = apply_transforms_and_defaults(value, config)
          value = coerce_value(value, config[:type], attr_name, path) unless value.nil?
          attributes[attr_name] = value
        end
      else
        # Fallback to basic id mapping if no attributes defined
        attributes[:id] = node_data_item["id"]
      end

      instance = target_class.new(attributes)

      # Handle nested connections
      if nested_includes.any?
        # Create a new loader to get the necessary data
        target_loader = @loader_class.new(target_class, included_connections: nested_includes)
        nested_mapper = ResponseMapper.new(
          graphql_type: target_loader.graphql_type,
          loader_class: @loader_class,
          defined_attributes: target_loader.defined_attributes,
          model_class: target_class,
          included_connections: nested_includes,
          query_name_proc: ->(type) { target_loader.query_name(type) }
        )
        nested_data = nested_mapper.extract_connection_data_from_node(node_data_item)

        nested_data.each do |nested_name, nested_records|
          instance.send("#{nested_name}=", nested_records)
        end
      end

      instance
    end

    def build_model_instance_from_attributes(node_data)
      attributes = {}
      @defined_attributes.each do |attr_name, config|
        value = extract_value_from_response(node_data, config[:path])
        attributes[attr_name] = transform_attribute_value(value, config, attr_name)
      end

      @model_class.new(attributes)
    end

    def extract_value_from_response(data, path)
      path_parts = path.split('.')
      data.dig(*path_parts)
    end

    def transform_attribute_value(value, config, attr_name)
      value = apply_transforms_and_defaults(value, config)
      value = coerce_value(value, config[:type], attr_name, config[:path]) unless value.nil?
      value
    end

    def apply_transforms_and_defaults(value, config)
      return value unless value.nil? || config[:transform]

      if value.nil?
        !config[:default].nil? ? config[:default] : config[:transform]&.call(value)
      else
        config[:transform]&.call(value) || value
      end
    end
  end
end
