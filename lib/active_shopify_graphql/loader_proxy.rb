# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Simple proxy class to handle loader delegation when using a specific API
  # This provides a consistent interface with Relation while using a custom loader
  class LoaderProxy
    def initialize(model_class, loader)
      @model_class = model_class
      @loader = loader
    end

    # Create a Relation with this loader's configuration
    # @return [Relation] A relation configured with this loader
    def all
      build_relation
    end

    # Delegate chainable methods to Relation
    def includes(*connection_names)
      build_relation.includes(*connection_names)
    end

    def select(*attribute_names)
      build_relation.select(*attribute_names)
    end

    def where(*args, **options)
      build_relation.where(*args, **options)
    end

    def find_by(conditions = {}, **options)
      build_relation.find_by(conditions, **options)
    end

    def find(id = nil)
      # For Customer Account API, if no ID is provided, load the current customer
      if id.nil? && @loader.is_a?(ActiveShopifyGraphQL::Loaders::CustomerAccountApiLoader)
        attributes = @loader.load_attributes
        return nil if attributes.nil?

        return @model_class.new(attributes)
      end

      # For other cases, require ID and use standard flow
      return nil if id.nil?

      build_relation.find(id)
    end

    attr_reader :loader

    def inspect
      "#{@model_class.name}(with_#{@loader.class.name.demodulize})"
    end
    alias to_s inspect

    private

    def build_relation
      Query::Relation.new(
        @model_class,
        loader_class: @loader.class,
        loader_extra_args: loader_extra_args
      )
    end

    # Returns extra arguments needed when creating a new loader of the same type
    # For CustomerAccountApiLoader, this includes the token
    def loader_extra_args
      if @loader.is_a?(ActiveShopifyGraphQL::Loaders::CustomerAccountApiLoader)
        [@loader.instance_variable_get(:@token)]
      else
        []
      end
    end
  end
end
