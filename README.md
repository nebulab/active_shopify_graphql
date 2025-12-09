# ActiveShopifyGraphQL

Bringing domain object peace of mind to the world of Shopify GraphQL APIs.

An ActiveRecord-like interface for Shopify's GraphQL APIs, supporting both Admin API and Customer Account API with automatic query building and response mapping.

## The problem it solves

GraphQL is excellent to provide the exact data for each specific place it's used. However this can be difficult to reason with where you have to deal with very similar payloads across your application. Using hashes or OpenStructs resulting from raw query responses can be cumbersome, as they may have different shapes if they are coming from a query or another.

This becomes even more complex when Shopify itself has different GraphQL schemas for the same types: good luck matching two `Customer` objects where one is coming from the [Admin API](https://shopify.dev/docs/api/admin-graphql/latest) and the other from the [Customer Account API](https://shopify.dev/docs/api/customer/latest).

This library moves the focus away from the raw query responses, bringing it back to the application domain with actual models. In this way, models present a stable interface, independent of the underlying schema they're coming from.

This library brings a Convention over Configuration approach to organize your custom data loaders, along with many ActiveRecord inspired features.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'active_shopify_graphql', git: "git://github.com/nebulab/active_shopify_graphql.git", branch: "main"
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install active_shopify_graphql

## Configuration

Before using ActiveShopifyGraphQL, you need to configure the API clients:

```ruby
# config/initializers/active_shopify_graphql.rb
Rails.configuration.to_prepare do
  ActiveShopifyGraphQL.configure do |config|
    # Configure the Admin API client (must respond to #execute(query, **variables))
    config.admin_api_client = ShopifyGraphQL::Client

    # Configure the Customer Account API client class (must have .from_config(token) class method)
    # and reponsd to #execute(query, **variables)
    config.customer_account_client_class = Shopify::Account::Client
  end
end
```

## Usage

### Basic Model Setup

Create a model that includes `ActiveShopifyGraphQL::Base` and define attributes directly:

```ruby
class Customer
  include ActiveShopifyGraphQL::Base

  # Define the GraphQL type
  graphql_type "Customer"

  # Define attributes with automatic GraphQL path inference and type coercion
  attribute :id, type: :string
  attribute :name, path: "displayName", type: :string
  attribute :email, path: "defaultEmailAddress.emailAddress", type: :string
  attribute :created_at, type: :datetime

  validates :id, presence: true

  def first_name
    name.split(" ").first
  end
end
```

### Defining Attributes

Attributes are now defined directly in the model class using the `attribute` method. The GraphQL fragments and response mapping are automatically generated!

#### Basic Attribute Definition

```ruby
class Customer
  include ActiveShopifyGraphQL::Base

  graphql_type "Customer"

  # Define attributes with automatic GraphQL path inference and type coercion
  attribute :id, type: :string
  attribute :name, path: "displayName", type: :string
  attribute :email, path: "defaultEmailAddress.emailAddress", type: :string
  attribute :created_at, type: :datetime

  # Custom transform example
  attribute :tags, type: :string, transform: ->(tags_array) { tags_array.join(", ") }
end
```

#### Attribute Definition Options

The `attribute` method supports several options for flexibility:

```ruby
attribute :name,
  path: "displayName",                    # Custom GraphQL path (auto-inferred if omitted)
  type: :string,                          # Type coercion (:string, :integer, :float, :boolean, :datetime)
  null: false,                            # Whether the attribute can be null (default: true)
  default: "a default value",             # The value to assign in case it's nil (default: nil)
  transform: ->(value) { value.upcase }   # Custom transformation block
```

**Auto-inference:** When `path` is omitted, it's automatically inferred by converting snake_case to camelCase (e.g., `display_name` → `displayName`).

**Nested paths:** Use dot notation for nested GraphQL fields (e.g., `"defaultEmailAddress.emailAddress"`).

**Type coercion:** Automatic conversion using ActiveModel types ensures type safety.

**Array handling:** Arrays are automatically preserved regardless of the specified type.

#### Metafield Attributes

Shopify metafields can be easily accessed using the `metafield_attribute` method:

```ruby
class Product
  include ActiveShopifyGraphQL::Base

  graphql_type "Product"

  # Regular attributes
  attribute :id, type: :string
  attribute :title, type: :string

  # Metafield attributes
  metafield_attribute :boxes_available, namespace: 'custom', key: 'available_boxes', type: :integer
  metafield_attribute :seo_description, namespace: 'seo', key: 'meta_description', type: :string
  metafield_attribute :product_data, namespace: 'custom', key: 'data', type: :json
  metafield_attribute :is_featured, namespace: 'custom', key: 'featured', type: :boolean, null: false
end
```

The metafield attributes automatically generate the correct GraphQL syntax and handle value extraction from either `value` or `jsonValue` fields based on the type.

#### API-Specific Attributes

For models that need different attributes depending on the API being used, you can define loader-specific overrides:

```ruby
class Customer
  include ActiveShopifyGraphQL::Base

  graphql_type "Customer"

  # Default attributes (used by all loaders)
  attribute :id, type: :string
  attribute :name, path: "displayName", type: :string

  for_loader ActiveShopifyGraphQL::Loaders::AdminApiLoader do
    attribute :email, path: "defaultEmailAddress.emailAddress", type: :string
    attribute :created_at, type: :datetime
  end

  # Customer Account API uses different field names
  for_loader ActiveShopifyGraphQL::Loaders::CustomerAccountApiLoader do
    attribute :email, path: "emailAddress.emailAddress", type: :string
    attribute :created_at, path: "creationDate", type: :datetime
  end
end
```

### Finding Records

Use the `find` method to retrieve records by ID:

```ruby
# Using Admin API (default)
customer = Customer.find("gid://shopify/Customer/123456789")
# You can also use just the ID number
customer = Customer.find(123456789)

# Using Customer Account API
customer = Customer.with_customer_account_api(token).find
```

### API Switching

Switch between Admin API and Customer Account API:

```ruby
# Use Admin API (default)
customer = Customer.find(id)

# Use Customer Account API with token
customer = Customer.with_customer_account_api(token).find

# Use Admin API explicitly
customer = Customer.with_admin_api.find(id)
```

### Querying Records

Use the `where` method to query multiple records using Shopify's search syntax:

```ruby
# Simple conditions
customers = Customer.where(email: "john@example.com")

# Range queries
customers = Customer.where(created_at: { gte: "2024-01-01", lt: "2024-02-01" })
customers = Customer.where(orders_count: { gte: 5 })

# Multi-word values are automatically quoted
customers = Customer.where(first_name: "John Doe")

# With limits
customers = Customer.where({ email: "john@example.com" }, limit: 100)
```

The `where` method automatically converts Ruby conditions into Shopify's GraphQL query syntax and validates that the query fields are supported by Shopify.

### Optimizing Queries with Select

Use the `select` method to only fetch specific attributes, reducing GraphQL query size and improving performance:

```ruby
# Only fetch id, name, and email
customer = Customer.select(:id, :name, :email).find(123)

# Works with where queries too
customers = Customer.select(:id, :name).where(country: "Canada")

# Always includes id even if not specified
customer = Customer.select(:name).find(123)
# This will still include :id in the GraphQL query
```

The `select` method validates that the specified attributes exist and automatically includes the `id` field for proper object identification.

## Associations

ActiveShopifyGraphQL provides ActiveRecord-like associations to define relationships between the Shopify native models and your own custom ones.

### Has Many Associations

Use `has_many` to define one-to-many relationships:

```ruby
class Customer
  include ActiveShopifyGraphQL::Base

  graphql_type "Customer"

  attribute :id, type: :string
  attribute :display_name, type: :string
  attribute :email, path: "defaultEmailAddress.emailAddress", type: :string
  attribute :created_at, type: :datetime

  # Define an association to one of your own ActiveRecord models
  # foreign_key maps the id of the GraphQL powered model to the rewards.shopify_customer_id table
  has_many :rewards, foreign_key: :shopify_customer_id

  validates :id, presence: true
end
```

#### Using the Association

```ruby
customer = Customer.find("gid://shopify/Customer/123456789") # or Customer.find(123456789)

# Access associated orders (lazy loaded)
customer.rewards
# => [#<Reward:0x... ]

```

### Has One Associations

Use `has_one` to define one-to-one relationships:

```ruby
class Order
  include ActiveShopifyGraphQL::Base

  has_one :billing_address, class_name: 'Address'
end
```

The associations automatically handle Shopify GID format conversion, extracting numeric IDs when needed for querying related records.

## GraphQL Connections

ActiveShopifyGraphQL supports GraphQL connections for loading related data from Shopify APIs. Connections provide both lazy and eager loading patterns with cursor-based pagination support.

### Defining Connections

Use the `connection` class method to define connections to other ActiveShopifyGraphQL models:

```ruby
class Customer
  include ActiveShopifyGraphQL::Base

  graphql_type 'Customer'

  attribute :id
  attribute :display_name, path: "displayName"
  attribute :email

  # Basic connection
  has_many_connected :orders, default_arguments: { first: 10 }

  # Connection with custom parameters
  has_many_connected :addresses,
    class_name: 'MailingAddress',    # Target model class (defaults to connection name)
    query_name: 'customerAddresses', # GraphQL query field (defaults to pluralized name)
    eager_load: true,                # Automatically eager load this connection (default: false)
    default_arguments: {             # Default arguments for the GraphQL query
      first: 5,                      # Number of records to fetch (default: 10)
      sort_key: 'CREATED_AT',        # Sort key (default: 'CREATED_AT')
      reverse: false                 # Sort direction (default: false for ascending)
    }
end

class Order
  include ActiveShopifyGraphQL::Base

  graphql_type 'Order'

  attribute :id
  attribute :name
  attribute :total_price, path: "totalPriceSet.shopMoney.amount"
end
```

### Lazy Loading (Default Behavior)

Connections are loaded lazily when accessed. A separate GraphQL query is fired when the connection is first accessed:

```ruby
customer = Customer.find(123456789)

# This creates a connection proxy but doesn't load data yet
orders_proxy = customer.orders
puts orders_proxy.loaded? # => false

# This triggers the GraphQL query and loads the data
orders = customer.orders.to_a
puts customer.orders.loaded? # => true (for this specific proxy instance)

# Connection proxies implement Enumerable
customer.orders.each do |order|
  puts order.name
end

# Array-like access methods
customer.orders.size        # Number of records
customer.orders.first       # First record
customer.orders.last        # Last record
customer.orders[0]          # Access by index
customer.orders.empty?      # Check if empty
```

### Runtime Parameter Overrides

You can override connection parameters at runtime:

```ruby
customer = Customer.find(123456789)

# Override default parameters for this call
recent_orders = customer.orders(
  first: 25,               # Fetch 25 records instead of default 10
  sort_key: 'UPDATED_AT',  # Sort by update date instead of creation date
  reverse: true            # Most recent first
).to_a
```

### Eager Loading with `includes`

Use `includes` to load connections in the same GraphQL query as the parent record, eliminating the N+1 query problem:

```ruby
# Load customer with orders and addresses in a single GraphQL query
customer = Customer.includes(:orders, :addresses).find(123456789)

# These connections are already loaded - no additional queries fired
orders = customer.orders      # Uses cached data
addresses = customer.addresses # Uses cached data

puts customer.orders.loaded?    # => This won't be a proxy since data was eager loaded
```

### Automatic Eager Loading

For connections that should always be loaded, you can use the `eager_load: true` parameter when defining the connection. This will automatically include the connection in all find and where queries without needing to explicitly use `includes`:

```ruby
class Customer
  include ActiveShopifyGraphQL::Base

  graphql_type 'Customer'

  attribute :id
  attribute :display_name, path: "displayName"

  # This connection will always be eager loaded
  connection :orders, eager_load: true

  # This connection will only be loaded lazily (default behavior)
  connection :addresses
end

# The orders connection is automatically loaded
customer = Customer.find(123456789)
orders = customer.orders      # Uses cached data - no additional query fired

# The addresses connection is lazy loaded
addresses = customer.addresses # This will fire a GraphQL query when first accessed
```

This feature is perfect for connections that are frequently accessed and should be included in most queries to avoid N+1 problems.

The `includes` method modifies the GraphQL fragment to include connection fields:

```graphql
query customer($id: ID!) {
  customer(id: $id) {
    # Regular customer fields
    id
    displayName

    # Eager-loaded connections
    orders(first: 10, sortKey: CREATED_AT, reverse: false) {
      edges {
        node {
          id
          name
          totalPriceSet {
            shopMoney {
              amount
            }
          }
        }
      }
    }
    addresses(first: 5, sortKey: CREATED_AT, reverse: false) {
      edges {
        node {
          id
          address1
          city
        }
      }
    }
  }
}
```

### Method Chaining

Connection methods support chaining with other query methods:

```ruby
# Chain includes with select for optimized queries
Customer.includes(:orders).select(:id, :display_name).find(123456789)

# Chain includes with where for filtered queries
Customer.includes(:orders).where(email: "john@example.com").first
```

### Testing Support

For testing, you can manually set connection data to avoid making real API calls:

```ruby
# In your tests
customer = Customer.new(id: 'gid://shopify/Customer/123')
mock_orders = [
  Order.new(id: 'gid://shopify/Order/1', name: '#1001'),
  Order.new(id: 'gid://shopify/Order/2', name: '#1002')
]

# Set mock data
customer.orders = mock_orders

# Now customer.orders returns the mock data
expect(customer.orders.size).to eq(2)
expect(customer.orders.first.name).to eq('#1001')
```

### Connection Configuration

Connections automatically infer sensible defaults but can be customized:

- **class_name**: Target model class name (defaults to connection name singularized and classified)
- **query_name**: GraphQL query field name (defaults to connection name pluralized)
- **foreign_key**: Field used to filter connection records (defaults to `{model_name}_id`)
- **loader_class**: Custom loader class (defaults to model's default loader)
- **eager_load**: Whether to automatically eager load this connection on find/where queries (default: false)
- **default_arguments**: Hash of default arguments to pass to the GraphQL query (e.g., `{ first: 10, sort_key: 'CREATED_AT' }`)

### Error Handling

Connection queries use the same error handling as regular model queries. If a connection query fails, an appropriate exception will be raised with details about the GraphQL error.

## Next steps

- [x] Support `Model.where(param: value)` proxying params to the GraphQL query attribute
- [x] Attribute-based model definition with automatic GraphQL fragment generation
- [x] Metafield attributes for easy access to Shopify metafields
- [x] Query optimization with `select` method
- [x] GraphQL connections with lazy and eager loading via `Customer.includes(:orders).find(id)`
- [ ] Better error handling and retry mechanisms for GraphQL API calls
- [ ] Caching layer for frequently accessed data
- [ ] Support for GraphQL subscriptions

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nebulab/active_shopify_graphql.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
