# frozen_string_literal: true

module ActiveShopifyGraphQL
  # A scope object that holds included connections for eager loading.
  # This allows chaining methods like find() and where() while maintaining
  # the included connections configuration.
  #
  # Internally delegates to LoaderProxy to avoid passing loader: parameters
  # through method chains.
  class IncludesScope
    attr_reader :model_class, :included_connections

    def initialize(model_class, included_connections)
      @model_class = model_class
      @included_connections = included_connections
    end

    # Delegate find to the loader proxy
    def find(id)
      loader_proxy.find(id)
    end

    # Delegate where to create a QueryScope with our eager-loading loader
    def where(conditions_or_first_condition = {}, *args, **options)
      # Handle string-based conditions with parameter binding
      if conditions_or_first_condition.is_a?(String)
        binding_params = args.empty? && options.any? ? [options] : args
        conditions = binding_params.empty? ? conditions_or_first_condition : [conditions_or_first_condition, *binding_params]
        return QueryScope.new(@model_class, conditions: conditions, loader: loader_proxy.loader)
      end

      # Handle hash-based conditions
      conditions = if conditions_or_first_condition.is_a?(Hash) && !conditions_or_first_condition.empty?
                     conditions_or_first_condition
                   else
                     options
                   end
      QueryScope.new(@model_class, conditions: conditions, loader: loader_proxy.loader)
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

    def loader_proxy
      @loader_proxy ||= LoaderSwitchable::LoaderProxy.new(
        @model_class,
        @model_class.default_loader.class.new(@model_class, included_connections: @included_connections),
        included_connections: @included_connections
      )
    end
  end
end
