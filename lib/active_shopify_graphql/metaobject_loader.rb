# frozen_string_literal: true

module ActiveShopifyGraphQL
  class MetaobjectLoader < Loaders::AdminApiLoader
    def context
      @context ||= LoaderContext.new(
        graphql_type: "Metaobject",
        loader_class: self.class,
        defined_attributes: defined_attributes,
        model_class: @model_class,
        included_connections: @included_connections,
        fields: @model_class.fields
      )
    end

    def build_collection_variables(conditions, per_page:, after: nil, before: nil)
      variables = super

      # Add type parameter for metaobjects query
      variables[:type] = @model_class.metaobject_type

      variables
    end

    private

    def resolve_graphql_type
      "Metaobject"
    end
  end
end
