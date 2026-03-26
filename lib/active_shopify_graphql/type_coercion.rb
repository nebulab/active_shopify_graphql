# frozen_string_literal: true

module ActiveShopifyGraphQL
  module TypeCoercion
    TYPE_CASTERS = {
      string: ActiveModel::Type::String.new,
      integer: ActiveModel::Type::Integer.new,
      float: ActiveModel::Type::Float.new,
      boolean: ActiveModel::Type::Boolean.new,
      datetime: ActiveModel::Type::DateTime.new
    }.freeze

    private

    def coerce_value(value, type)
      return nil if value.nil?
      return value if value.is_a?(Array)

      TYPE_CASTERS.fetch(type, ActiveModel::Type::Value.new).cast(value)
    end
  end
end
