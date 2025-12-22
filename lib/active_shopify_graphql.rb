# frozen_string_literal: true

require "active_support"
require "active_support/concern"
require "active_model"
require "active_model/attribute_assignment"
require "active_model/validations"
require "active_model/naming"
require "globalid"

require "zeitwerk"
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "active_shopify_graphql" => "ActiveShopifyGraphQL",
  "graphql_associations" => "GraphQLAssociations"
)
loader.setup

module ActiveShopifyGraphQL
  class Error < StandardError; end
  class ObjectNotFoundError < Error; end
end
