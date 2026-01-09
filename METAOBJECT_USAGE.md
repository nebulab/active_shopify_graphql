# Metaobject Usage Examples

This file demonstrates how to use Shopify Metaobjects with active_shopify_graphql.

## Basic Metaobject Model

Define a metaobject model with fields:

```ruby
class ApplicationShopifyMetaobject < ActiveShopifyGraphQL::Metaobject
  # Abstract base class for your app's metaobjects
end

class Provider < ApplicationShopifyMetaobject
  # Type inferred as "provider" from class name
  # Or explicitly set: metaobject_type "custom_provider_type"

  field :description
  field :rating, type: :integer
  field :certified, type: :boolean, default: false
  field :contact_info, type: :json, transform: ->(val) { parse_contact(val) }
end
```

## Querying Metaobjects

Find a single metaobject by ID:

```ruby
provider = Provider.find("gid://shopify/Metaobject/123")
# => #<Provider id="gid://shopify/Metaobject/123" description="Premium Service" ...>
```

Query with conditions:

```ruby
providers = Provider.where(certified: true).to_a
# Generates GraphQL: metaobjects(type: "provider", query: "fields.certified:true", first: 250) { ... }

providers = Provider.where(description: "premium").to_a
# Generates GraphQL: metaobjects(type: "provider", query: "fields.description:premium", first: 250) { ... }
```

Chain query operations:

```ruby
Provider.where(certified: true).limit(10).to_a
Provider.where(rating: { gte: 4 }).in_pages(of: 50) do |page|
  page.each { |provider| process(provider) }
end
```

## Metaobject Connections via Metafields

Define a connection to a metaobject through a metafield:

```ruby
class Product < ActiveShopifyGraphQL::Model
  graphql_type "Product"

  attribute :id
  attribute :title

  # Define metafield for the connection
  metafield_attribute :provider, namespace: "custom", key: "provider"

  # Connect to the Provider metaobject
  has_one_connected_metaobject :provider
end
```

Use the connection:

```ruby
product = Product.find("gid://shopify/Product/456")
provider = product.provider
# => #<Provider ...>

# Eager loading
Product.includes(:provider).find("gid://shopify/Product/456") do |product|
  product.provider  # Pre-loaded, no additional query
end
```

## Field Type Coercion and Transforms

Fields support type coercion and custom transforms:

```ruby
class Provider < ApplicationShopifyMetaobject
  field :rating, type: :integer
  field :active, type: :boolean
  field :price, type: :float

  field :normalized_name, transform: ->(name) { name&.strip&.upcase }
  field :contact_info, type: :json,
        transform: ->(json) { JSON.parse(json) rescue {} }
end

# When loading from GraphQL response, these transforms are applied
provider = Provider.find("gid://shopify/Metaobject/123")
provider.rating  # Coerced to integer
provider.normalized_name  # Transformed: stripped and uppercased
```

## Inheritance

Metaobject models support inheritance for shared fields:

```ruby
class ApplicationShopifyMetaobject < ActiveShopifyGraphQL::Metaobject
  field :display_name
  field :created_at, type: :datetime
end

class Provider < ApplicationShopifyMetaobject
  # Inherits display_name and created_at
  field :description
  field :rating, type: :integer
end

provider = Provider.new(...)
provider.display_name  # Available from parent
provider.created_at    # Available from parent
provider.description   # Defined on Provider
```

## Custom Metaobject Type

Override the inferred metaobject type:

```ruby
class ServiceProvider < ApplicationShopifyMetaobject
  # Would normally be inferred as "service_provider"
  metaobject_type "custom_provider_type"

  field :name
end

# Generates queries with: metaobjects(type: "custom_provider_type", ...)
```
