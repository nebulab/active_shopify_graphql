# frozen_string_literal: true

module ActiveShopifyGraphQL
  class Loader
    # Override this to define special behavior at loader initialization
    def initialize(**)
      # no-op
    end

    # Override this to define the GraphQL fragment for the model
    def fragment
      raise NotImplementedError, "#{self.class} must implement fragment"
    end

    # Override this to define the query name (can accept model_type for customization)
    def query_name(model_type = 'customer')
      model_type.downcase
    end

    # Override this to define the fragment name (can accept model_type for customization)
    def fragment_name(model_type = 'Customer')
      "#{model_type}Fragment"
    end

    # Builds the complete GraphQL query using the fragment
    def graphql_query(model_type = 'Customer')
      query_name_value = query_name(model_type)
      fragment_name_value = fragment_name(model_type)

      <<~GRAPHQL
        #{fragment}
        query get#{model_type}($id: ID!) {
          #{query_name_value}(id: $id) {
            ...#{fragment_name_value}
          }
        }
      GRAPHQL
    end

    # Override this to map the GraphQL response to model attributes
    def map_response_to_attributes(response_data)
      raise NotImplementedError, "#{self.class} must implement map_response_to_attributes"
    end

    # Executes the GraphQL query and returns the mapped attributes hash
    # The model instantiation is handled by the calling code
    def load_attributes(id, model_type = 'Customer')
      query = graphql_query(model_type)
      variables = { id: id }

      response_data = execute_graphql_query(query, **variables)

      return nil if response_data.nil?

      map_response_to_attributes(response_data)
    end

    private

    def execute_graphql_query
      raise NotImplementedError, "#{self.class} must implement execute_graphql_query"
    end
  end
end
