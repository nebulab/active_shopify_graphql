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

    # Create a new context for a different model (for connection targets)
    def for_model(new_model_class, new_graphql_type: nil, new_attributes: nil, new_connections: [])
      self.class.new(
        graphql_type: new_graphql_type || new_model_class.graphql_type_for_loader(loader_class),
        loader_class: loader_class,
        defined_attributes: new_attributes || new_model_class.attributes_for_loader(loader_class),
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
  end
end
