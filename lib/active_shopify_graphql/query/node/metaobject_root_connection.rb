# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Query
    class Node
      class MetaobjectRootConnection < RootConnection
        attr_reader :metaobject_type

        def initialize(query_name:, fragment_name:, metaobject_type:, variables: {}, fragments: [], singular: false)
          @metaobject_type = metaobject_type
          super(query_name: query_name, fragment_name: fragment_name, variables: variables, fragments: fragments, singular: singular)
        end

        private

        def field_signature
          params = build_field_parameters(@variables.compact)

          # Add type parameter for metaobjects
          type_param = "type: \"#{@metaobject_type}\""
          params.unshift(type_param)

          params.empty? ? "" : "(#{params.join(', ')})"
        end
      end
    end
  end
end
