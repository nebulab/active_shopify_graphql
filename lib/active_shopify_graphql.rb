# frozen_string_literal: true

require 'active_support'
require 'active_support/inflector'
require 'active_support/concern'
require 'active_support/core_ext/object/blank'
require 'active_model'
require 'globalid'

require_relative "active_shopify_graphql/version"
require_relative "active_shopify_graphql/configuration"
require_relative "active_shopify_graphql/gid_helper"
require_relative "active_shopify_graphql/query"
require_relative "active_shopify_graphql/loader"
require_relative "active_shopify_graphql/loaders/admin_api_loader"
require_relative "active_shopify_graphql/loaders/customer_account_api_loader"
require_relative "active_shopify_graphql/loader_switchable"
require_relative "active_shopify_graphql/finder_methods"
require_relative "active_shopify_graphql/associations"
require_relative "active_shopify_graphql/connections"
require_relative "active_shopify_graphql/attributes"
require_relative "active_shopify_graphql/metafield_attributes"
require_relative "active_shopify_graphql/search_query"
require_relative "active_shopify_graphql/base"

module ActiveShopifyGraphQL
  class Error < StandardError; end
end
