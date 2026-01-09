# frozen_string_literal: true

module ActiveShopifyGraphQL::Model::MetaobjectFields
  extend ActiveSupport::Concern

  class_methods do
    def field(name, type: :string, null: true, default: nil, transform: nil)
      config = { type: type, null: null, default: default, transform: transform }

      if @current_loader_context
        @loader_contexts ||= {}
        @loader_contexts[@current_loader_context] ||= {}
        @loader_contexts[@current_loader_context][name] = config
      else
        @fields ||=
          if superclass.instance_variable_defined?(:@fields)
            superclass.instance_variable_get(:@fields).dup
          else
            {}
          end
        @fields[name] = config
      end

      attr_accessor name unless method_defined?(name) || method_defined?("#{name}=")
    end
  end
end
