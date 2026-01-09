# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Query
    class Node
      class MetaobjectField < Node
        def initialize(name:, key:)
          json_value_node = Node::Field.new(name: "jsonValue")
          super(name: key, alias_name: name.to_s, children: [json_value_node])
        end

        def to_s
          "#{@alias_name}: field(key: \"#{@name}\") { #{render_children.first} }"
        end
      end
    end
  end
end
