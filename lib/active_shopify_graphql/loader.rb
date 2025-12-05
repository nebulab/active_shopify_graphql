# frozen_string_literal: true

require 'active_model/type'
require 'global_id'
require_relative 'fragment'
require_relative 'response_mapper'
require_relative 'record_query'
require_relative 'connection_query'
require_relative 'executor'
require_relative 'collection_query'
require_relative 'connection_loader'

module ActiveShopifyGraphQL
  class Loader # rubocop:disable Metrics/ClassLength
    class << self
      # Set or get the GraphQL type for this loader
      def graphql_type(type = nil)
        return @graphql_type = type if type

        # Try to get GraphQL type from associated model class first
        return model_class.graphql_type_for_loader(self) if model_class.respond_to?(:graphql_type_for_loader)

        @graphql_type || raise(NotImplementedError, "#{self} must define graphql_type or have an associated model with graphql_type")
      end

      # Set or get the client type for this loader (:admin_api or :customer_account_api)
      def client_type(type = nil)
        return @client_type = type if type

        @client_type || :admin_api # Default to admin API
      end

      # Get the model class associated with this loader
      def model_class
        @model_class ||= infer_model_class
      end

      # Set the model class associated with this loader
      attr_writer :model_class

      # Get all defined attributes (includes both direct and model attributes)
      def attributes
        defined_attributes
      end

      # Get all defined metafields (includes both direct and model metafields)
      def metafields
        defined_metafields
      end

      # Get attributes from the model class for this loader
      def defined_attributes
        return {} unless model_class.respond_to?(:attributes_for_loader)

        # Get attributes defined in the model for this loader class
        model_class.attributes_for_loader(self)
      end

      # Get metafields from the model class
      def defined_metafields
        return {} unless model_class.respond_to?(:metafields)

        model_class.metafields
      end

      # Set or get the GraphQL fragment fields for this loader
      # Example:
      #   fragment <<~GRAPHQL
      #     id
      #     displayName
      #     createdAt
      #     defaultEmailAddress {
      #       emailAddress
      #     }
      #     tags
      #   GRAPHQL
      def fragment(fields = nil)
        return @fragment_fields = fields if fields

        @fragment_fields || raise(NotImplementedError, "#{self} must define fragment")
      end

      private

      # Infer the model class from the GraphQL type
      # e.g., graphql_type "Customer" -> Customer
      def infer_model_class
        type = @graphql_type
        return nil unless type

        # Try to find the class based on GraphQL type
        begin
          Object.const_get(type)
        rescue NameError
          # If not found, return nil - the model class may not exist yet
          nil
        end
      end
    end

    # Initialize loader with optional model class and selected attributes
    def initialize(model_class = nil, selected_attributes: nil, included_connections: nil, **)
      @model_class = model_class || self.class.model_class
      @selected_attributes = selected_attributes&.map(&:to_sym)
      @included_connections = included_connections || []
    end

    # Get GraphQL type for this loader instance
    def graphql_type
      if @model_class && @model_class.respond_to?(:graphql_type_for_loader)
        @model_class.graphql_type_for_loader(self.class)
      elsif @model_class && @model_class.respond_to?(:name) && @model_class.name
        # Infer from model class name if available
        @model_class.name.demodulize
      else
        self.class.graphql_type
      end
    end

    # Get defined attributes for this loader instance
    def defined_attributes
      attrs = if @model_class.respond_to?(:attributes_for_loader)
                @model_class.attributes_for_loader(self.class)
              else
                self.class.defined_attributes
              end

      # Filter by selected attributes if specified
      if @selected_attributes
        selected_attrs = {}
        (@selected_attributes + [:id]).uniq.each do |attr|
          selected_attrs[attr] = attrs[attr] if attrs.key?(attr)
        end
        selected_attrs
      else
        attrs
      end
    end

    # Get defined metafields for this loader instance
    def defined_metafields
      if @model_class.respond_to?(:metafields)
        @model_class.metafields
      else
        self.class.defined_metafields
      end
    end

    # Returns the complete GraphQL fragment built from class-level fragment fields
    def fragment
      Fragment.new(
        graphql_type: graphql_type,
        loader_class: self.class,
        defined_attributes: defined_attributes,
        model_class: @model_class,
        included_connections: @included_connections,
        fragment_name_proc: ->(type) { fragment_name(type) }
      ).to_s
    end

    # Get or create a RecordQuery instance for this loader
    def record_query
      @record_query ||= RecordQuery.new(
        graphql_type: graphql_type,
        loader_class: self.class,
        defined_attributes: defined_attributes,
        model_class: @model_class,
        included_connections: @included_connections,
        fragment_generator: -> { fragment },
        fragment_name_proc: ->(type) { fragment_name(type) }
      )
    end

    # Get or create a ConnectionQuery instance for this loader
    def connection_query
      @connection_query ||= ConnectionQuery.new(
        graphql_type: graphql_type,
        loader_class: self.class,
        defined_attributes: defined_attributes,
        model_class: @model_class,
        included_connections: @included_connections,
        fragment_name_proc: ->(type) { fragment_name(type) }
      )
    end

    # Delegate query building methods to RecordQuery class
    def query_name(model_type = nil)
      record_query.query_name(model_type)
    end

    def fragment_name(model_type = nil)
      record_query.fragment_name(model_type)
    end

    def graphql_query(model_type = nil)
      record_query.graphql_query(model_type)
    end

    # Override this to map the GraphQL response to model attributes
    def map_response_to_attributes(response_data)
      # Use attributes-based mapping if attributes are defined, otherwise require manual implementation
      attrs = defined_attributes
      raise NotImplementedError, "#{self.class} must implement map_response_to_attributes" unless attrs.any?

      mapper = ResponseMapper.new(
        graphql_type: graphql_type,
        loader_class: self.class,
        defined_attributes: defined_attributes,
        model_class: @model_class,
        included_connections: @included_connections,
        query_name_proc: ->(type) { query_name(type) }
      )
      attributes = mapper.map_response_from_attributes(response_data)

      # If we have included connections, extract and cache them
      if @included_connections.any? && @model_class.respond_to?(:connections)
        connection_data = mapper.extract_connection_data(response_data)
        attributes[:_connection_cache] = connection_data unless connection_data.empty?
      end

      attributes
    end

    # Executes the GraphQL query and returns the mapped attributes hash
    # The model instantiation is handled by the calling code
    def load_attributes(id)
      query = graphql_query(graphql_type)
      variables = { id: id }

      executor = Executor.new(self.class.client_type)
      response_data = executor.execute(query, **variables)

      return nil if response_data.nil?

      map_response_to_attributes(response_data)
    end

    # Executes a collection query using Shopify's search syntax and returns an array of mapped attributes
    # @param conditions [Hash] The conditions to query
    # @param limit [Integer] The maximum number of records to return (default: 250, max: 250)
    # @return [Array<Hash>] Array of attribute hashes or empty array if none found
    def load_collection(conditions = {}, limit: 250)
      collection_query = CollectionQuery.new(
        graphql_type: graphql_type,
        query_builder: record_query,
        query_name_proc: ->(type) { query_name(type) },
        fragment_name_proc: ->(type) { fragment_name(type) },
        fragment_generator: -> { fragment },
        map_response_proc: ->(response) { map_response_to_attributes(response) },
        client_type: self.class.client_type
      )
      collection_query.execute(conditions, limit: limit)
    end

    # Load records for a connection query
    # @param query_name [String] The connection field name (e.g., 'orders', 'addresses')
    # @param variables [Hash] The GraphQL variables (first, sort_key, reverse, query)
    # @param parent [Object] The parent object that owns this connection
    # @param connection_config [Hash] The connection configuration (optional, used to determine if nested)
    # @return [Array<Object>] Array of model instances
    def load_connection_records(query_name, variables, parent = nil, connection_config = nil)
      connection_loader = ConnectionLoader.new(
        connection_query: connection_query,
        loader_class: self.class,
        client_type: self.class.client_type,
        response_mapper_factory: lambda {
          ResponseMapper.new(
            graphql_type: graphql_type,
            loader_class: self.class,
            defined_attributes: defined_attributes,
            model_class: @model_class,
            included_connections: @included_connections,
            query_name_proc: ->(type) { query_name(type) }
          )
        }
      )
      connection_loader.load_records(query_name, variables, parent, connection_config)
    end
  end
end
