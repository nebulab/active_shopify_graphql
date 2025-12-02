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

  for_loader ActiveShopifyGraphQL::AdminApiLoader do
    attribute :email, path: "defaultEmailAddress.emailAddress", type: :string
    attribute :created_at, type: :datetime
  end

  # Customer Account API uses different field names
  for_loader ActiveShopifyGraphQL::CustomerAccountApiLoader do
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

## Next steps

- [x] Support `Model.where(param: value)` proxying params to the GraphQL query attribute
- [x] Attribute-based model definition with automatic GraphQL fragment generation
- [x] Metafield attributes for easy access to Shopify metafields
- [x] Query optimization with `select` method
- [ ] Eager loading of GraphQL connections via `Customer.includes(:orders).find(id)` in a single GraphQL query
- [ ] Better error handling and retry mechanisms for GraphQL API calls
- [ ] Caching layer for frequently accessed data
- [ ] Support for GraphQL subscriptions

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nebulab/active_shopify_graphql.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
