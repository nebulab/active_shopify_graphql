# frozen_string_literal: true

require 'active_model/type'
require 'global_id'

module ActiveShopifyGraphQL
  # The Loader acts as a stateless orchestrator that:
  # - Receives a model class and delegates to it for GraphQL type and attribute definitions
  # - Builds a LoaderContext that encapsulates all query-building parameters
  # - Delegates query construction to Query::QueryBuilder
  # - Delegates response mapping to Response::ResponseMapper
  # - Executes GraphQL queries via subclass-specific implementations (perform_graphql_query)
  #
  # == Subclass Requirements
  #
  # Subclasses must implement:
  # - +perform_graphql_query(query, **variables)+ - Execute the query against the appropriate API
  #
  # == Usage
  #
  #   loader = AdminApiLoader.new(Customer, selected_attributes: [:id, :email])
  #   attributes = loader.load_attributes("gid://shopify/Customer/123")
  #   customer = Customer.new(attributes)
  #
  # @see LoaderContext For query-building context management
  # @see Query::QueryBuilder For GraphQL query construction
  # @see Response::ResponseMapper For response-to-attribute mapping
  class Loader
    # Initialize loader with model class and configuration
    def initialize(model_class, selected_attributes: nil, included_connections: nil, **)
      @model_class = model_class
      @selected_attributes = selected_attributes&.map(&:to_sym)
      @included_connections = included_connections || []
    end

    # Build the LoaderContext for this loader instance
    def context
      @context ||= LoaderContext.new(
        graphql_type: resolve_graphql_type,
        loader_class: self.class,
        defined_attributes: defined_attributes,
        model_class: @model_class,
        included_connections: @included_connections
      )
    end

    # Get defined attributes for this loader instance
    def defined_attributes
      filter_selected_attributes(@model_class.attributes_for_loader(self.class))
    end

    # Map the GraphQL response to model attributes
    def map_response_to_attributes(response_data, parent_instance: nil)
      mapper = create_response_mapper
      attributes = mapper.map_response(response_data)
      cache_connections(mapper, response_data, target: attributes, parent_instance: parent_instance)
      attributes
    end

    # Check if this loader has included connections
    def has_included_connections?
      @included_connections&.any?
    end

    # Executes the GraphQL query and returns the mapped attributes hash
    # @param id [String] The GID of the record to load
    # @return [Hash, nil] Attribute hash with connection cache, or nil if not found
    def load_attributes(id)
      query = Query::QueryBuilder.build_single_record_query(context)
      response_data = execute_query(query, id: id)
      return nil if response_data.nil?

      map_response_to_attributes(response_data)
    end

    # Executes a paginated collection query that returns attributes and page info
    # Executes a paginated collection query that returns attributes and page info
    # @param conditions [Hash] Search conditions
    # @param per_page [Integer] Number of records per page
    # @param after [String, nil] Cursor to fetch records after
    # @param before [String, nil] Cursor to fetch records before
    # @param query_scope [Query::Scope] The query scope for navigation
    # @return [PaginatedResult] A paginated result with attribute hashes and page info
    def load_paginated_collection(conditions:, per_page:, query_scope:, after: nil, before: nil)
      collection_query_name = context.query_name.pluralize
      variables = build_collection_variables(
        conditions,
        per_page: per_page,
        after: after,
        before: before
      )

      query = Query::QueryBuilder.build_paginated_collection_query(
        context,
        query_name: collection_query_name,
        variables: variables
      )

      response = execute_query_and_validate_search_response(query, **variables)
      map_paginated_response(response, collection_query_name, query_scope)
    end

    # Load records for a connection query
    def load_connection_records(query_name, variables, parent = nil, connection_config = nil)
      connection_loader = Connections::ConnectionLoader.new(context, loader_instance: self)
      connection_loader.load_records(query_name, variables, parent, connection_config)
    end

    # Abstract method for executing GraphQL queries
    def perform_graphql_query(query, **variables)
      raise NotImplementedError, "#{self.class} must implement perform_graphql_query"
    end

    private

    def create_response_mapper
      Response::ResponseMapper.new(context)
    end

    def should_log?
      ActiveShopifyGraphQL.configuration.log_queries && ActiveShopifyGraphQL.configuration.logger
    end

    def log_query(api_name, query, variables)
      return unless should_log?

      ActiveShopifyGraphQL.configuration.logger.info("ActiveShopifyGraphQL Query (#{api_name}):\n#{query}")
      ActiveShopifyGraphQL.configuration.logger.info("ActiveShopifyGraphQL Variables:\n#{variables}")
    end

    def cache_connections(mapper, response_data, target:, parent_instance: nil)
      return unless @included_connections.any?

      connection_data = mapper.extract_connection_data(response_data, parent_instance: parent_instance)
      return if connection_data.empty?

      case target
      when Hash
        target[:_connection_cache] = connection_data
      else
        target.instance_variable_set(:@_connection_cache, connection_data)
      end
    end

    def resolve_graphql_type
      raise ArgumentError, "#{self.class} requires a model_class" unless @model_class

      @model_class.graphql_type_for_loader(self.class)
    end

    def filter_selected_attributes(attrs)
      return attrs unless @selected_attributes

      selected = {}
      (@selected_attributes + [:id]).uniq.each do |attr|
        selected[attr] = attrs[attr] if attrs.key?(attr)
      end
      selected
    end

    def validate_search_query_response(response)
      return unless response.dig("extensions", "search")

      warnings = response["extensions"]["search"].flat_map { |s| s["warnings"] || [] }
      return if warnings.empty?

      messages = warnings.map { |w| "#{w['field']}: #{w['message']}" }
      raise ArgumentError, "Shopify query validation failed: #{messages.join(', ')}"
    end

    def execute_query(query, **variables)
      perform_graphql_query(query, **variables)
    end

    def execute_query_and_validate_search_response(query, **variables)
      response = execute_query(query, **variables)
      validate_search_query_response(response)
      response
    end

    def build_collection_variables(conditions, per_page:, after: nil, before: nil)
      search_query = SearchQuery.new(conditions)
      variables = { query: search_query.to_s }

      if before
        variables[:last] = per_page
        variables[:before] = before
      else
        variables[:first] = per_page
        variables[:after] = after if after
      end

      variables.compact
    end

    def map_node_to_attributes(node_data)
      single_response = { "data" => { context.query_name => node_data } }
      map_response_to_attributes(single_response)
    end

    def map_paginated_response(response_data, collection_query_name, query_scope)
      connection_data = response_data.dig("data", collection_query_name)
      return empty_paginated_result(query_scope) unless connection_data

      page_info_data = connection_data["pageInfo"] || {}
      page_info = Response::PageInfo.new(page_info_data)

      nodes = connection_data["nodes"] || []
      attributes_array = nodes.filter_map { |node_data| map_node_to_attributes(node_data) }

      Response::PaginatedResult.new(
        attributes: attributes_array,
        model_class: @model_class,
        page_info: page_info,
        query_scope: query_scope
      )
    end

    def empty_paginated_result(query_scope)
      Response::PaginatedResult.new(
        attributes: [],
        model_class: @model_class,
        page_info: Response::PageInfo.new,
        query_scope: query_scope
      )
    end
  end
end
