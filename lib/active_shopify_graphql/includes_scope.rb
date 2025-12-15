# frozen_string_literal: true

module ActiveShopifyGraphQL
  # A scope object that holds included connections for eager loading.
  # This allows chaining methods like find() and where() while maintaining
  # the included connections configuration.
  class IncludesScope
    attr_reader :model_class, :included_connections

    def initialize(model_class, included_connections)
      @model_class = model_class
      @included_connections = included_connections
    end

    # Delegate find to the model class with a custom loader
    def find(id, loader: nil)
      loader ||= default_loader
      @model_class.find(id, loader: loader)
    end

    # Delegate where to the model class with a custom loader
    def where(*args, **options)
      loader = options.delete(:loader) || default_loader
      @model_class.where(*args, **options.merge(loader: loader))
    end

    # Delegate select to create a new scope with select
    def select(*attributes)
      selected_scope = @model_class.select(*attributes)
      # Chain the includes on top of select
      IncludesScope.new(selected_scope, @included_connections)
    end

    # Allow chaining includes calls
    def includes(*connection_names)
      @model_class.includes(*(@included_connections + connection_names).uniq)
    end

    private

    def default_loader
      @default_loader ||= @model_class.default_loader.class.new(
        @model_class,
        included_connections: @included_connections
      )
    end
  end
end
