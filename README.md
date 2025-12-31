<div align="center">

# ActiveShopifyGraphQL

**Bringing Read Only (for now) ActiveRecord-like domain modeling to Shopify GraphQL APIs**

[![Gem Version](https://badge.fury.io/rb/active_shopify_graphql.svg)](https://badge.fury.io/rb/active_shopify_graphql)
[![Spec](https://github.com/nebulab/active_shopify_graphql/actions/workflows/test.yml/badge.svg)](https://github.com/nebulab/active_shopify_graphql/actions/workflows/test.yml)
[![Lint](https://github.com/nebulab/active_shopify_graphql/actions/workflows/lint.yml/badge.svg)](https://github.com/nebulab/active_shopify_graphql/actions/workflows/lint.yml)

</div>

<div align="center">
Support for both Admin and Customer Account APIs with automatic query building, response mapping, and N+1-free connections.
</div>

---

## 🚀 Quick Start

```bash
gem install active_shopify_graphql
```

```ruby
# Configure in pure Ruby
ActiveShopifyGraphQL.configure do |config|
  config.admin_api_client = ShopifyGraphQL::Client
  config.customer_account_client_class = Shopify::Account::Client
end

# Or define a Rails initializer
Rails.configuration.to_prepare do
  ActiveShopifyGraphQL.configure do |config|
    config.admin_api_client = ShopifyGraphQL::Client
    config.customer_account_client_class = Shopify::Account::Client
  end
end

# Define your model
class Customer < ActiveShopifyGraphQL::Model
  graphql_type "Customer" # Optional as it's auto inferred

  attribute :id, type: :string
  attribute :name, path: "displayName", type: :string
  attribute :email, path: "defaultEmailAddress.emailAddress", type: :string
  attribute :created_at, type: :datetime

  has_many_connected :orders, default_arguments: { first: 10 }
end

# Use it like ActiveRecord
customer = Customer.find(123456789)
customer.name                         # => "John Doe"
customer.orders.to_a                  # => [#<Order:0x...>, ...]

Customer.where(email: "@example.com")
Customer.includes(:orders).find(id)
```

---

## ✨ Why?

### The Problem

GraphQL is powerful, but dealing with raw responses is painful:

```ruby
# Before: The struggle
response = shopify_client.execute(query)
customer = response["data"]["customer"]
email = customer["defaultEmailAddress"]["emailAddress"]
created_at = Time.parse(customer["createdAt"])
orders = customer["orders"]["nodes"].map { |o| parse_order(o) }
# Different API? Different field names. Good luck!
```

**Problems:**
- ❌ Different schemas for Admin API vs any other API
- ❌ Inconsistent data shapes across queries
- ❌ Manual type conversions everywhere
- ❌ N+1 query problems with connections
- ❌ No validation or business logic layer

### The Solution

```ruby
# After: Peace of mind
customer = Customer.includes(:orders).find(123456789)
customer.email                # => "john@example.com"
customer.created_at           # => #<DateTime>
customer.orders.to_a          # Lazily loaded as a single query
```

**Benefits:**
- ✅ **Single source of truth** — Models, not hashes
- ✅ **Type-safe attributes** — Automatic coercion
- ✅ **Unified across APIs** — Same model, different loaders
- ✅ **Optional eager loading** — Save points by default, eager load when needed
- ✅ **ActiveRecord-like** — Familiar, idiomatic Ruby and Rails

---

## 📚 Table of Contents

- [Installation](#installation)
- [Configuration](#configuration)
- [Core Concepts](#core-concepts)
- [Features](#features)
- [API Reference](#api-reference)
- [Advanced Topics](#advanced-topics)
- [Development](#development)

---

## Installation

Add to your Gemfile:

```ruby
gem "active_shopify_graphql"
```

Or install globally:

```bash
gem install active_shopify_graphql
```

---

## Configuration

Configure your Shopify GraphQL clients:

```ruby
# config/initializers/active_shopify_graphql.rb
Rails.configuration.to_prepare do
  ActiveShopifyGraphQL.configure do |config|
    # Admin API (must respond to #execute(query, **variables))
    config.admin_api_client = ShopifyGraphQL::Client

    # Customer Account API (must have .from_config(token) and #execute)
    config.customer_account_client_class = Shopify::Account::Client
  end
end
```

---

## Core Concepts

### Models

Models are the heart of ActiveShopifyGraphQL. They define:

- **GraphQL type** → Which Shopify schema type they map to
- **Attributes** → Fields to fetch and their types
- **Associations** → Relationships to other models
- **Connections** → GraphQL connections for related data
- **Business logic** → Validations, methods, transformations

### Attributes

Attributes auto-generate GraphQL fragments and handle response mapping:

```ruby
class Customer < ActiveShopifyGraphQL::Model
  graphql_type "Customer"

  # Auto-inferred path: displayName
  attribute :name, type: :string

  # Custom path with dot notation
  attribute :email, path: "defaultEmailAddress.emailAddress", type: :string

  # Custom transformation
  attribute :plain_id, path: "id", transform: ->(gid) { gid.split("/").last }
end
```

### Connections

Connections to related Shopify data with lazy/eager loading:

```ruby
class Customer < ActiveShopifyGraphQL::Model
  # Lazy by default — loaded on first access
  has_many_connected :orders

  # Always eager load — no N+1 queries
  has_many_connected :addresses, eager_load: true, default_arguments: { first: 5 }

  # Scoped connection with custom arguments
  has_many_connected :recent_orders,
    query_name: "orders",
    default_arguments: { first: 5, reverse: true, sort_key: "CREATED_AT" }
end
```

---

## Features

### 🏗️ Attribute Definition

Define attributes with automatic GraphQL generation:

```ruby
class Product < ActiveShopifyGraphQL::Model
  graphql_type "Product"

  # Simple attribute (path auto-inferred as "title")
  attribute :title, type: :string

  # Custom path
  attribute :price, path: "priceRange.minVariantPrice.amount", type: :float

  # With default
  attribute :description, type: :string, default: "No description"

  # Custom transformation
  attribute :slug, path: "handle", transform: ->(handle) { handle.parameterize }

  # Nullable validation
  attribute :vendor, type: :string, null: false
end
```

#### Metafields

Easy access to Shopify metafields:

```ruby
class Product < ActiveShopifyGraphQL::Model
  graphql_type "Product"

  attribute :id, type: :string
  attribute :title, type: :string

  # Metafield attributes
  metafield_attribute :boxes_available, namespace: 'custom', key: 'available_boxes', type: :integer
  metafield_attribute :seo_description, namespace: 'seo', key: 'meta_description', type: :string
  metafield_attribute :product_data, namespace: 'custom', key: 'data', type: :json
end
```

#### Raw GraphQL

For advanced features like union types:

```ruby
class Product < ActiveShopifyGraphQL::Model
  graphql_type "Product"

  # Raw GraphQL injection for union types
  attribute :provider_id,
    path: "provider_id.reference.id", # first part must match the attribute name as the field is aliased to that
    type: :string,
    raw_graphql: 'metafield(namespace: "custom", key: "provider") { reference { ... on Metaobject { id } } }'
end
```

#### API-Specific Attributes

Different fields per API:

```ruby
class Customer < ActiveShopifyGraphQL::Model
  graphql_type "Customer"

  attribute :id, type: :string
  attribute :name, path: "displayName", type: :string

  # Admin API specific
  for_loader ActiveShopifyGraphQL::Loaders::AdminApiLoader do
    attribute :email, path: "defaultEmailAddress.emailAddress", type: :string
  end

  # Customer Account API specific
  for_loader ActiveShopifyGraphQL::Loaders::CustomerAccountApiLoader do
    attribute :email, path: "emailAddress.emailAddress", type: :string
  end
end
```

### Querying

#### Finding Records

```ruby
# By GID or numeric ID
customer = Customer.find("gid://shopify/Customer/123456789")
customer = Customer.find(123456789)

# With specific API
Customer.with_customer_account_api(token).find
Customer.with_admin_api.find(123456789)
```

#### Filtering

```ruby
# Hash queries (auto-escaped)
Customer.where(email: "john@example.com")

# Range queries
Customer.where(created_at: { gte: "2024-01-01", lt: "2024-02-01" })
Customer.where(orders_count: { gte: 5 })

# Wildcards (string query)
Customer.where("email:*@example.com")

# Parameter binding (safe)
Customer.where("email::email", email: "john@example.com")

# With limits
Customer.where(email: "@gmail.com").limit(100)
```

#### Query Optimization

```ruby
# Select only needed fields
Customer.select(:id, :name).find(123)

# Combine with includes (N+1-free)
Customer.includes(:orders).select(:id, :name).where(first_name: "Andrea")
```

### Pagination

Automatic cursor-based pagination:

```ruby
# Automatic pagination with limit
# Query for non-empty SKUs
ProductVariant.where("-sku:''").limit(100).to_a

# Manual pagination
page = ProductVariant.where("sku:FRZ*").in_pages(of: 50)
page.has_next_page?    # => true
next_page = page.next_page

# Batch processing
ProductVariant.where("sku:FRZ*").in_pages(of: 10) do |page|
  page.each { |variant| process(variant) }
end

# Lazy enumeration
scope = Customer.where(email: "*@example.com")
scope.each { |c| puts c.name }  # Executes query
scope.first                      # Fetches just first
```

### Connections

#### Lazy Loading

```ruby
customer = Customer.find(123)

# Not loaded yet
customer.orders.loaded?    # => false

# Loads on access (separate query)
orders = customer.orders.to_a
customer.orders.loaded?    # => true

# Enumerable
customer.orders.each { |order| puts order.name }
customer.orders.size
customer.orders.first
```

#### Eager Loading

```ruby
# Load in single query (no N+1!)
customer = Customer.includes(:orders, :addresses).find(123)

# Already loaded
orders = customer.orders      # No additional query
addresses = customer.addresses
```

#### Automatic Eager Loading

```ruby
class Customer < ActiveShopifyGraphQL::Model
  # Always loaded without explicit includes
  has_many_connected :orders, eager_load: true
end

customer = Customer.find(123)
orders = customer.orders      # Already loaded
```

#### Runtime Parameters

```ruby
customer = Customer.find(123)

# Override defaults
customer.orders(first: 25, sort_key: 'UPDATED_AT', reverse: true).to_a
```

#### Inverse Relationships

```ruby
class Product < ActiveShopifyGraphQL::Model
  has_many_connected :variants, inverse_of: :product
end

class ProductVariant < ActiveShopifyGraphQL::Model
  has_one_connected :product, inverse_of: :variants
end

# Bidirectional caching — no redundant queries
product = Product.includes(:variants).find(123)
product.variants.each do |variant|
  variant.product  # Uses cached parent, no query runs
end
```

### ActiveRecord Associations

Bridge between your ActiveRecord models and Shopify GraphQL:

```ruby
class Reward < ApplicationRecord
  include ActiveShopifyGraphQL::GraphQLAssociations

  belongs_to_graphql :customer
  has_one_graphql :primary_address, class_name: "Address"
  has_many_graphql :variants, class_name: "ProductVariant"
end

reward = Reward.find(1)
reward.customer        # Loads Customer from shopify_customer_id
reward.variants        # Queries ProductVariant.where({})
```

---

## API Reference

### Attribute Options

```ruby
attribute :name,
  path: "displayName",                    # GraphQL path (auto-inferred if omitted)
  type: :string,                          # Type coercion
  null: false,                            # Can be null? (default: true)
  default: "value",                       # Default value (default: nil)
  transform: ->(v) { v.upcase }           # Custom transform
```

**Supported Types:** `:string`, `:integer`, `:float`, `:boolean`, `:datetime`

### Connection Options

```ruby
has_many_connected :orders,
  class_name: "Order",                    # Target class (default: connection name)
  query_name: "orders",                   # GraphQL field (default: pluralized)
  default_arguments: {                    # Default query args
    first: 10,
    sort_key: 'CREATED_AT',
    reverse: false
  },
  eager_load: true,                       # Auto eager load? (default: false)
  inverse_of: :customer                   # Inverse connection (optional)
```

### Association Options

```ruby
has_many :rewards,
  foreign_key: :shopify_customer_id       # ActiveRecord column
  primary_key: :id                        # Model attribute (default: :id)

has_one :billing_address,
  class_name: "Address"
```

---

## Advanced Topics

### Application Base Class

Create a base class for shared behavior:

```ruby
# app/models/application_shopify_gql_record.rb
class ApplicationShopifyRecord < ActiveShopifyGraphQL::Model
  attribute :id, transform: ->(gid) { gid.split("/").last }
  attribute :gid, path: "id"
end

# Then inherit
class Customer < ApplicationShopifyRecord
  graphql_type "Customer"
  attribute :name, path: "displayName"
end
```

### Custom Loaders

Create your own loaders for specialized behavior:

```ruby
class MyCustomLoader < ActiveShopifyGraphQL::Loader
  def fragment
    # Return GraphQL fragment string
  end

  def map_response_to_attributes(response)
    # Map response to attribute hash
  end
end

# Use it
Customer.with_loader(MyCustomLoader).find(123)
```

### Testing

Mock data for tests:

```ruby
# Mock associations
customer = Customer.new(id: 'gid://shopify/Customer/123')
customer.orders = [Order.new(id: 'gid://shopify/Order/1')]

# Mock connections
customer.orders = mock_orders
expect(customer.orders.size).to eq(1)
```

---

## Development

```bash
# Install dependencies
bin/setup

# Run tests
bundle exec rake spec

# Run console
bin/console

# Lint
bundle exec rubocop
```

---

## Roadmap

- [x] Attribute-based model definition
- [x] Metafield attributes
- [x] Query optimization with `select`
- [x] GraphQL connections with lazy/eager loading
- [x] Cursor-based pagination
- [ ] Metaobjects as models
- [ ] Builtin instrumentation to track query costs
- [ ] Advanced error handling and retry mechanisms
- [ ] Caching layer
- [ ] Chained `.where` with `.not` support
- [ ] Basic mutation support

---

## Contributing

Bug reports and pull requests are welcome on GitHub at [nebulab/active_shopify_graphql](https://github.com/nebulab/active_shopify_graphql).

---

## License

The gem is available as open source under the [MIT License](https://opensource.org/licenses/MIT).

---

<div align="center">

Made by [Nebulab](https://nebulab.com)

</div>
