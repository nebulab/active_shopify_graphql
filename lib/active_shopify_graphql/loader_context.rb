# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Value object that encapsulates the shared context needed across query building,
  # response mapping, and connection loading operations.
  class LoaderContext
    attr_reader :graphql_type, :loader_class, :defined_attributes, :model_class, :included_connections

    def initialize(graphql_type:, loader_class:, defined_attributes:, model_class:, included_connections: [])
      @graphql_type = graphql_type
      @loader_class = loader_class
      @defined_attributes = defined_attributes
      @model_class = model_class
      @included_connections = Array(included_connections)
    end

    # Create a new context with different included connections (for nested loading)
    def with_connections(new_connections)
      self.class.new(
        graphql_type: graphql_type,
        loader_class: loader_class,
        defined_attributes: defined_attributes,
        model_class: model_class,
        included_connections: new_connections
      )
    end

    # Create a new context for a different model (for connection targets)
    def for_model(new_model_class, new_graphql_type: nil, new_attributes: nil, new_connections: [])
      self.class.new(
        graphql_type: new_graphql_type || infer_graphql_type(new_model_class),
        loader_class: loader_class,
        defined_attributes: new_attributes || infer_attributes(new_model_class),
        model_class: new_model_class,
        included_connections: new_connections
      )
    end

    # Helper methods delegated from context
    def query_name
      graphql_type.camelize(:lower)
    end

    def fragment_name
      "#{graphql_type}Fragment"
    end

    def connections
      return {} unless model_class

      model_class.connections
    end

    private

    def infer_graphql_type(klass)
      if klass.respond_to?(:graphql_type_for_loader)
        klass.graphql_type_for_loader(loader_class)
      elsif klass.respond_to?(:graphql_type)
        klass.graphql_type
      elsif klass.respond_to?(:name) && klass.name
        klass.name.demodulize
      else
        raise ArgumentError, "Cannot infer graphql_type for #{klass}"
      end
    end

    def infer_attributes(klass)
      return klass.attributes_for_loader(loader_class) if klass.respond_to?(:attributes_for_loader)

      {}
    end
  end
end
