# frozen_string_literal: true

require 'active_support'
require 'active_support/inflector'
require 'active_support/concern'
require 'active_support/core_ext/object/blank'
require 'active_model'
require 'globalid'

# Core
require_relative "active_shopify_graphql/version"
require_relative "active_shopify_graphql/configuration"
require_relative "active_shopify_graphql/gid_helper"
require_relative "active_shopify_graphql/loader_context"

# Query building
require_relative "active_shopify_graphql/query/node"
require_relative "active_shopify_graphql/query/node/field"
require_relative "active_shopify_graphql/query/node/singular"
require_relative "active_shopify_graphql/query/node/connection"
require_relative "active_shopify_graphql/query/node/fragment"
require_relative "active_shopify_graphql/query/node/raw"
require_relative "active_shopify_graphql/query/node/single_record"
require_relative "active_shopify_graphql/query/node/current_customer"
require_relative "active_shopify_graphql/query/node/collection"
require_relative "active_shopify_graphql/query/node/nested_connection"
require_relative "active_shopify_graphql/query/node/root_connection"
require_relative "active_shopify_graphql/query/query_builder"
require_relative "active_shopify_graphql/query/relation"
require_relative "active_shopify_graphql/query/scope"

# Response handling
require_relative "active_shopify_graphql/response/response_mapper"
require_relative "active_shopify_graphql/response/page_info"
require_relative "active_shopify_graphql/response/paginated_result"

# Connections
require_relative "active_shopify_graphql/connections/connection_loader"
require_relative "active_shopify_graphql/connections/connection_proxy"

# Loaders
require_relative "active_shopify_graphql/loader"
require_relative "active_shopify_graphql/loaders/admin_api_loader"
require_relative "active_shopify_graphql/loaders/customer_account_api_loader"

# Model concerns
require_relative "active_shopify_graphql/model/graphql_type_resolver"
require_relative "active_shopify_graphql/model/loader_switchable"
require_relative "active_shopify_graphql/model/finder_methods"
require_relative "active_shopify_graphql/model/associations"
require_relative "active_shopify_graphql/model/connections"
require_relative "active_shopify_graphql/model/attributes"
require_relative "active_shopify_graphql/model/metafield_attributes"

# AR/PORO associations to GraphQL
require_relative "active_shopify_graphql/graphql_associations"

# Search query
require_relative "active_shopify_graphql/search_query"

# Base module
require_relative "active_shopify_graphql/base"

module ActiveShopifyGraphQL
  class Error < StandardError; end
  class ObjectNotFoundError < Error; end
end
