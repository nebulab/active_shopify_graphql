# frozen_string_literal: true

require_relative "active_shopify_graphql/version"
require_relative "active_shopify_graphql/configuration"
require_relative "active_shopify_graphql/base"
require_relative "active_shopify_graphql/associations"
require_relative "active_shopify_graphql/connections"
require_relative "active_shopify_graphql/finder_methods"
require_relative "active_shopify_graphql/loader_switchable"
require_relative "active_shopify_graphql/loader"
require_relative "active_shopify_graphql/admin_api_loader"
require_relative "active_shopify_graphql/customer_account_api_loader"

module ActiveShopifyGraphQL
  class Error < StandardError; end
end
