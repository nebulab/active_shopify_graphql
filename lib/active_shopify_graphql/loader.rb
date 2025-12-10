# frozen_string_literal: true

require 'active_model/type'
require 'global_id'

module ActiveShopifyGraphQL
  # Base loader class that orchestrates GraphQL query execution and response mapping.
  # Refactored to use LoaderContext for cleaner parameter management.
  class Loader
    class << self
      # Set or get the GraphQL type for this loader
      def graphql_type(type = nil)
        return @graphql_type = type if type

        # Try to get GraphQL type from associated model class first
        return model_class.graphql_type_for_loader(self) if model_class

        @graphql_type || raise(NotImplementedError, "#{self} must define graphql_type")
      end

      # Get the model class associated with this loader
      def model_class
        @model_class ||= infer_model_class
      end

      attr_writer :model_class

      # Get attributes from the model class for this loader
      def defined_attributes
        return {} unless model_class

        model_class.attributes_for_loader(self)
      end

      private

      def infer_model_class
        return nil unless @graphql_type

        Object.const_get(@graphql_type)
      rescue NameError
        nil
      end
    end

    # Initialize loader with optional model class and configuration
    def initialize(model_class = nil, selected_attributes: nil, included_connections: nil, **)
      @model_class = model_class || self.class.model_class
      @selected_attributes = selected_attributes&.map(&:to_sym)
      @included_connections = included_connections || []
    end

    # Build the LoaderContext for this loader instance
    def context
      @context ||= LoaderContext.new(
        graphql_type: graphql_type,
        loader_class: self.class,
        defined_attributes: defined_attributes,
        model_class: @model_class,
        included_connections: @included_connections
      )
    end

    # Get GraphQL type for this loader instance
    def graphql_type
      GraphqlTypeResolver.resolve(model_class: @model_class, loader_class: self.class)
    end

    # Get defined attributes for this loader instance
    def defined_attributes
      attrs = if @model_class
                @model_class.attributes_for_loader(self.class)
              else
                self.class.defined_attributes
              end

      filter_selected_attributes(attrs)
    end

    # Returns the complete GraphQL fragment
    def fragment
      FragmentBuilder.new(context).build
    end

    # Delegate query building methods
    def query_name(model_type = nil)
      (model_type || graphql_type).downcase
    end

    def fragment_name(model_type = nil)
      "#{model_type || graphql_type}Fragment"
    end

    def graphql_query(_model_type = nil)
      QueryTree.build_single_record_query(context)
    end

    # Map the GraphQL response to model attributes
    def map_response_to_attributes(response_data)
      mapper = ResponseMapper.new(context)
      attributes = mapper.map_response(response_data)

      # If we have included connections, extract and cache them
      if @included_connections.any?
        connection_data = mapper.extract_connection_data(response_data)
        attributes[:_connection_cache] = connection_data unless connection_data.empty?
      end

      attributes
    end

    # Executes the GraphQL query and returns the mapped attributes hash
    def load_attributes(id)
      query = graphql_query
      response_data = perform_graphql_query(query, id: id)

      return nil if response_data.nil?

      map_response_to_attributes(response_data)
    end

    # Executes a collection query using Shopify's search syntax
    def load_collection(conditions = {}, limit: 250)
      search_query = SearchQuery.new(conditions)
      collection_query_name = query_name.pluralize
      variables = { query: search_query.to_s, first: limit }

      query = QueryTree.build_collection_query(
        context,
        query_name: collection_query_name,
        variables: variables,
        connection_type: :nodes_only
      )

      response = perform_graphql_query(query, **variables)
      validate_search_response(response)
      map_collection_response(response, collection_query_name)
    end

    # Load records for a connection query
    def load_connection_records(query_name, variables, parent = nil, connection_config = nil)
      connection_loader = ConnectionLoader.new(context, loader_instance: self)
      connection_loader.load_records(query_name, variables, parent, connection_config)
    end

    # Abstract method for executing GraphQL queries
    def perform_graphql_query(query, **variables)
      raise NotImplementedError, "#{self.class} must implement perform_graphql_query"
    end

    private

    def filter_selected_attributes(attrs)
      return attrs unless @selected_attributes

      selected = {}
      (@selected_attributes + [:id]).uniq.each do |attr|
        selected[attr] = attrs[attr] if attrs.key?(attr)
      end
      selected
    end

    def validate_search_response(response)
      return unless response.dig("extensions", "search")

      warnings = response["extensions"]["search"].flat_map { |s| s["warnings"] || [] }
      return if warnings.empty?

      messages = warnings.map { |w| "#{w['field']}: #{w['message']}" }
      raise ArgumentError, "Shopify query validation failed: #{messages.join(', ')}"
    end

    def map_collection_response(response_data, collection_query_name)
      nodes = response_data.dig("data", collection_query_name, "nodes")
      return [] unless nodes&.any?

      nodes.filter_map do |node_data|
        single_response = { "data" => { query_name => node_data } }
        map_response_to_attributes(single_response)
      end
    end
  end
end
