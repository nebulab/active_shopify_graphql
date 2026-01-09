# frozen_string_literal: true

module ActiveShopifyGraphQL
  class Metaobject < Model
    class << self
      def inherited(subclass)
        super
        subclass.include ActiveShopifyGraphQL::Model::MetaobjectFields
      end

      def default_loader_class
        ActiveShopifyGraphQL::MetaobjectLoader
      end

      def metaobject_type(type = nil)
        @metaobject_type = type if type
        @metaobject_type ||= inferred_metaobject_type
      end

      attr_writer :metaobject_type, :fields

      def fields
        @fields ||=
          if superclass.respond_to?(:fields)
            superclass.fields.dup
          else
            {}
          end
      end

      def fields_for_loader(_loader_class)
        fields
      end

      private

      def inferred_metaobject_type
        return nil unless respond_to?(:name) && name

        name.demodulize.underscore
      end
    end
  end
end
