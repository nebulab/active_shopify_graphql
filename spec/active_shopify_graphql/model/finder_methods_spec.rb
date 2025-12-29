# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Model::FinderMethods do
  describe ".find" do
    it "accepts numeric ID and normalizes to GID" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:id]).to eq("gid://shopify/Customer/123")
        { "data" => { "customer" => { "id" => "gid://shopify/Customer/123", "email" => "test@example.com" } } }
      end

      customer = customer_class.find(123)

      expect(customer).not_to be_nil
      expect(customer.id).to eq("gid://shopify/Customer/123")
    end

    it "accepts string numeric ID and normalizes to GID" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:id]).to eq("gid://shopify/Customer/456")
        { "data" => { "customer" => { "id" => "gid://shopify/Customer/456", "email" => "test@example.com" } } }
      end

      customer = customer_class.find("456")

      expect(customer).not_to be_nil
      expect(customer.id).to eq("gid://shopify/Customer/456")
    end

    it "accepts existing GID and uses it as-is" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:id]).to eq("gid://shopify/Customer/789")
        { "data" => { "customer" => { "id" => "gid://shopify/Customer/789", "email" => "test@example.com" } } }
      end

      customer = customer_class.find("gid://shopify/Customer/789")

      expect(customer).not_to be_nil
    end

    it "raises ObjectNotFoundError when record is not found" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      allow(mock_client).to receive(:execute).and_return(nil)

      expect { customer_class.find(999) }.to raise_error(ActiveShopifyGraphQL::ObjectNotFoundError, "Couldn't find Customer with id=999")
    end

    it "raises ArgumentError when called without id using Admin API" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)

      expect { customer_class.find }.to raise_error(ArgumentError, "find requires an ID argument unless using Customer Account API")
    end

    it "fetches current customer when called without id using Customer Account API" do
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      mock_client = instance_double("CustomerAccountClient")
      allow(mock_client).to receive(:query).and_return({
                                                         "data" => {
                                                           "customer" => {
                                                             "id" => "gid://shopify/Customer/123",
                                                             "email" => "current@customer.com"
                                                           }
                                                         }
                                                       })
      customer_account_client_class = class_double("CustomerAccountClient")
      allow(customer_account_client_class).to receive(:from_config).with("test_token").and_return(mock_client)
      ActiveShopifyGraphQL.configure { |c| c.customer_account_client_class = customer_account_client_class }

      customer = customer_class.with_customer_account_api("test_token").find

      expect(customer).not_to be_nil
      expect(customer.id).to eq("gid://shopify/Customer/123")
      expect(customer.email).to eq("current@customer.com")
    end

    it "fetches current customer with includes when using Customer Account API" do
      order_class = build_order_class
      stub_const("Order", order_class)
      customer_class = build_customer_class(with_orders: true)
      stub_const("Customer", customer_class)
      mock_client = instance_double("CustomerAccountClient")
      allow(mock_client).to receive(:query).and_return({
                                                         "data" => {
                                                           "customer" => {
                                                             "id" => "gid://shopify/Customer/123",
                                                             "email" => "current@customer.com",
                                                             "orders" => {
                                                               "nodes" => [
                                                                 { "id" => "gid://shopify/Order/456", "name" => "#1001" }
                                                               ]
                                                             }
                                                           }
                                                         }
                                                       })
      customer_account_client_class = class_double("CustomerAccountClient")
      allow(customer_account_client_class).to receive(:from_config).with("test_token").and_return(mock_client)
      ActiveShopifyGraphQL.configure { |c| c.customer_account_client_class = customer_account_client_class }

      customer = customer_class.with_customer_account_api("test_token").includes(:orders).find

      expect(customer).not_to be_nil
      expect(customer.id).to eq("gid://shopify/Customer/123")
      expect(customer.email).to eq("current@customer.com")
      expect(customer.orders).not_to be_empty
      expect(customer.orders.first.name).to eq("#1001")
    end
  end

  describe ".find_by" do
    it "returns the first matching record" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:query]).to eq("email:'john@example.com'")
        expect(variables[:first]).to eq(1)
        { "data" => { "customers" => { "nodes" => [
          { "id" => "gid://shopify/Customer/123", "displayName" => "John", "email" => "john@example.com" }
        ] } } }
      end

      result = customer_class.find_by(email: "john@example.com")

      expect(result).not_to be_nil
      expect(result.id).to eq("gid://shopify/Customer/123")
      expect(result.email).to eq("john@example.com")
    end

    it "returns nil when no record is found" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      allow(mock_client).to receive(:execute).and_return({ "data" => { "customers" => { "nodes" => [] } } })

      result = customer_class.find_by(email: "nonexistent@example.com")

      expect(result).to be_nil
    end

    it "handles multiple conditions" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:query]).to eq("email:'john@example.com' AND first_name:'John'")
        expect(variables[:first]).to eq(1)
        { "data" => { "customers" => { "nodes" => [
          { "id" => "gid://shopify/Customer/123", "displayName" => "John", "email" => "john@example.com" }
        ] } } }
      end

      result = customer_class.find_by(email: "john@example.com", first_name: "John")

      expect(result).not_to be_nil
      expect(result.id).to eq("gid://shopify/Customer/123")
    end

    it "handles range conditions" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:query]).to include("id:>=100")
        expect(variables[:first]).to eq(1)
        { "data" => { "customers" => { "nodes" => [
          { "id" => "gid://shopify/Customer/100", "email" => "test@example.com" }
        ] } } }
      end

      result = customer_class.find_by(id: { gte: 100 })

      expect(result).not_to be_nil
    end

    it "supports hash style with options" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      custom_loader = ActiveShopifyGraphQL::Loaders::AdminApiLoader.new(customer_class)
      expect(mock_client).to receive(:execute).and_return(
        { "data" => { "customers" => { "nodes" => [
          { "id" => "gid://shopify/Customer/123", "email" => "test@example.com" }
        ] } } }
      )

      result = customer_class.find_by({ email: "test@example.com" }, loader: custom_loader)

      expect(result).not_to be_nil
    end

    it "raises ArgumentError for invalid attributes" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      mock_response = {
        "data" => { "customers" => { "nodes" => [] } },
        "extensions" => {
          "search" => [{
            "path" => ["customers"],
            "query" => "invalid_field:test",
            "warnings" => [{ "field" => "invalid_field", "message" => "Invalid search field for this query." }]
          }]
        }
      }
      allow(mock_client).to receive(:execute).and_return(mock_response)

      expect { customer_class.find_by(invalid_field: "test") }.to raise_error(ArgumentError, /Shopify query validation failed/)
    end

    it "works with select method" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      expect(mock_client).to receive(:execute) do |query, **variables|
        expect(query).to include("id")
        expect(query).to include("email")
        expect(query).not_to include("displayName")
        expect(variables[:first]).to eq(1)
        { "data" => { "customers" => { "nodes" => [
          { "id" => "gid://shopify/Customer/123", "email" => "john@example.com" }
        ] } } }
      end

      result = customer_class.select(:email).find_by(email: "john@example.com")

      expect(result).not_to be_nil
      expect(result.email).to eq("john@example.com")
    end
  end

  describe ".where" do
    it "builds correct Shopify query syntax for simple conditions" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:query]).to eq("email:'john@example.com' AND first_name:'John'")
        { "data" => { "customers" => { "pageInfo" => { "hasNextPage" => false }, "nodes" => [
          { "id" => "gid://shopify/Customer/123", "displayName" => "John", "email" => "john@example.com" }
        ] } } }
      end

      results = customer_class.where(email: "john@example.com", first_name: "John").to_a

      expect(results.size).to eq(1)
      expect(results.first.id).to eq("gid://shopify/Customer/123")
    end

    it "raises ArgumentError when Shopify returns field validation warnings" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      mock_response = {
        "data" => { "customers" => { "pageInfo" => { "hasNextPage" => false }, "nodes" => [] } },
        "extensions" => {
          "search" => [{
            "path" => ["customers"],
            "query" => "invalid_field:test",
            "warnings" => [{ "field" => "invalid_field", "message" => "Invalid search field for this query." }]
          }]
        }
      }
      allow(mock_client).to receive(:execute).and_return(mock_response)

      expect { customer_class.where(invalid_field: "test").to_a }.to raise_error(ArgumentError, /Shopify query validation failed/)
    end

    it "handles range conditions correctly" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:query]).to include("id:>=100")
        expect(variables[:query]).to include("id:<200")
        { "data" => { "customers" => { "pageInfo" => { "hasNextPage" => false }, "nodes" => [] } } }
      end

      customer_class.where(id: { gte: 100, lt: 200 }).to_a
    end

    it "handles quoted values for multi-word strings" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:query]).to eq("first_name:'John Doe'")
        { "data" => { "customers" => { "pageInfo" => { "hasNextPage" => false }, "nodes" => [] } } }
      end

      customer_class.where(first_name: "John Doe").to_a
    end

    it "returns empty array when no results" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      allow(mock_client).to receive(:execute).and_return({ "data" => { "customers" => { "pageInfo" => { "hasNextPage" => false }, "nodes" => [] } } })

      results = customer_class.where(email: "nonexistent@example.com")

      expect(results).to be_empty
    end

    it "respects limit with chainable method" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:first]).to eq(100)
        { "data" => { "customers" => { "pageInfo" => { "hasNextPage" => false }, "nodes" => [] } } }
      end

      customer_class.where(email: "test@example.com").limit(100).to_a
    end

    it "defaults per_page to 250" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:first]).to eq(250)
        { "data" => { "customers" => { "pageInfo" => { "hasNextPage" => false }, "nodes" => [] } } }
      end

      customer_class.where(email: "test@example.com").to_a
    end

    context "with string-based conditions (raw query)" do
      it "accepts string conditions for wildcard matching" do
        mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
        ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
        product_variant_class = build_product_variant_class
        stub_const("ProductVariant", product_variant_class)
        expect(mock_client).to receive(:execute) do |_query, **variables|
          expect(variables[:query]).to eq("sku:*")
          { "data" => { "productVariants" => { "pageInfo" => { "hasNextPage" => false }, "nodes" => [] } } }
        end

        product_variant_class.where("sku:*").to_a
      end

      it "does not sanitize raw string queries" do
        mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
        ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
        customer_class = build_customer_class
        stub_const("Customer", customer_class)
        expect(mock_client).to receive(:execute) do |_query, **variables|
          expect(variables[:query]).to eq("email:test@example.com AND first_name:John")
          { "data" => { "customers" => { "pageInfo" => { "hasNextPage" => false }, "nodes" => [] } } }
        end

        customer_class.where("email:test@example.com AND first_name:John").to_a
      end

      it "allows complex raw queries with parentheses and OR" do
        mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
        ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
        customer_class = build_customer_class
        stub_const("Customer", customer_class)
        expect(mock_client).to receive(:execute) do |_query, **variables|
          expect(variables[:query]).to eq("(status:open OR status:pending) AND total_price:>100")
          { "data" => { "customers" => { "pageInfo" => { "hasNextPage" => false }, "nodes" => [] } } }
        end

        customer_class.where("(status:open OR status:pending) AND total_price:>100").to_a
      end

      it "can chain string-based conditions with limit" do
        mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
        ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
        product_variant_class = build_product_variant_class
        stub_const("ProductVariant", product_variant_class)
        expect(mock_client).to receive(:execute) do |_query, **variables|
          expect(variables[:query]).to eq("sku:*")
          expect(variables[:first]).to eq(50)
          { "data" => { "productVariants" => { "pageInfo" => { "hasNextPage" => false }, "nodes" => [] } } }
        end

        product_variant_class.where("sku:*").limit(50).to_a
      end
    end

    context "hash vs string query distinction" do
      it "escapes wildcards in hash conditions" do
        mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
        ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
        product_variant_class = build_product_variant_class
        stub_const("ProductVariant", product_variant_class)
        expect(mock_client).to receive(:execute) do |_query, **variables|
          expect(variables[:query]).to eq("sku:'*'")
          { "data" => { "productVariants" => { "pageInfo" => { "hasNextPage" => false }, "nodes" => [] } } }
        end

        product_variant_class.where(sku: "*").to_a
      end

      it "does not escape wildcards in string conditions" do
        mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
        ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
        product_variant_class = build_product_variant_class
        stub_const("ProductVariant", product_variant_class)
        expect(mock_client).to receive(:execute) do |_query, **variables|
          expect(variables[:query]).to eq("sku:*")
          { "data" => { "productVariants" => { "pageInfo" => { "hasNextPage" => false }, "nodes" => [] } } }
        end

        product_variant_class.where("sku:*").to_a
      end
    end

    context "with parameter binding" do
      it "binds positional parameters safely" do
        mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
        ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
        product_variant_class = build_product_variant_class
        stub_const("ProductVariant", product_variant_class)
        expect(mock_client).to receive(:execute) do |_query, **variables|
          expect(variables[:query]).to eq("sku:'Good ol\\' value' product_id:123")
          { "data" => { "productVariants" => { "pageInfo" => { "hasNextPage" => false }, "nodes" => [] } } }
        end

        product_variant_class.where("sku:? product_id:?", "Good ol' value", 123).to_a
      end

      it "binds named parameters safely from hash argument" do
        mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
        ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
        product_variant_class = build_product_variant_class
        stub_const("ProductVariant", product_variant_class)
        expect(mock_client).to receive(:execute) do |_query, **variables|
          expect(variables[:query]).to eq("sku:'A-SKU' product_id:123")
          { "data" => { "productVariants" => { "pageInfo" => { "hasNextPage" => false }, "nodes" => [] } } }
        end

        product_variant_class.where("sku::sku product_id::product_id", { sku: "A-SKU", product_id: 123 }).to_a
      end

      it "binds named parameters safely from keyword arguments" do
        mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
        ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
        product_variant_class = build_product_variant_class
        stub_const("ProductVariant", product_variant_class)
        expect(mock_client).to receive(:execute) do |_query, **variables|
          expect(variables[:query]).to eq("sku:'foo'")
          { "data" => { "productVariants" => { "pageInfo" => { "hasNextPage" => false }, "nodes" => [] } } }
        end

        product_variant_class.where("sku::sku", sku: "foo").to_a
      end

      it "escapes special characters in bound parameters" do
        mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
        ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
        customer_class = build_customer_class
        stub_const("Customer", customer_class)
        expect(mock_client).to receive(:execute) do |_query, **variables|
          expect(variables[:query]).to eq("email:'test\\\"quote\\\"@example.com'")
          { "data" => { "customers" => { "pageInfo" => { "hasNextPage" => false }, "nodes" => [] } } }
        end

        customer_class.where("email:?", 'test"quote"@example.com').to_a
      end

      it "can chain parameter binding with limit" do
        mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
        ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
        product_variant_class = build_product_variant_class
        stub_const("ProductVariant", product_variant_class)
        expect(mock_client).to receive(:execute) do |_query, **variables|
          expect(variables[:query]).to eq("sku:'TEST'")
          expect(variables[:first]).to eq(50)
          { "data" => { "productVariants" => { "pageInfo" => { "hasNextPage" => false }, "nodes" => [] } } }
        end

        product_variant_class.where("sku:?", "TEST").limit(50).to_a
      end
    end
  end

  describe ".select" do
    it "returns a Relation that can be used for method chaining" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)

      selected_relation = customer_class.select(:id, :email)

      expect(selected_relation).to be_a(ActiveShopifyGraphQL::Query::Relation)
      expect(selected_relation).to respond_to(:find)
      expect(selected_relation).to respond_to(:where)
    end

    it "creates a relation that builds a loader with only selected attributes" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)

      selected_relation = customer_class.select(:id, :email)
      loader = selected_relation.send(:loader)

      expect(loader.defined_attributes.keys).to contain_exactly(:id, :email)
    end

    it "always includes id even if not explicitly selected" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)

      selected_relation = customer_class.select(:email)
      loader = selected_relation.send(:loader)

      expect(loader.defined_attributes.keys).to include(:id)
      expect(loader.defined_attributes.keys).to include(:email)
    end

    it "generates GraphQL fragments with only selected attributes" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)

      selected_relation = customer_class.select(:email)
      loader = selected_relation.send(:loader)
      fragment = ActiveShopifyGraphQL::Query::QueryBuilder.new(loader.context).build_fragment.to_s

      expect(fragment).to include("id")
      expect(fragment).to include("email")
      expect(fragment).not_to include("displayName")
    end

    it "validates that selected attributes exist" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)

      expect { customer_class.select(:nonexistent_attribute) }.to raise_error(ArgumentError, /Invalid attributes/)
    end

    it "provides helpful error message with available attributes" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)

      expect { customer_class.select(:bad_attr) }.to raise_error(ArgumentError) do |error|
        expect(error.message).to include("Available attributes are:")
      end
    end

    it "preserves the model class reference" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)

      selected_relation = customer_class.select(:id, :email)

      expect(selected_relation.model_class).to eq(customer_class)
    end

    it "works with find method" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      expect(mock_client).to receive(:execute) do |query, **variables|
        expect(query).to include("id")
        expect(query).to include("email")
        expect(query).not_to include("displayName")
        expect(variables[:id].to_s).to eq("gid://shopify/Customer/123")
        { "data" => { "customer" => { "id" => "gid://shopify/Customer/123", "email" => "john@example.com" } } }
      end

      customer = customer_class.select(:email).find(123)

      expect(customer).to be_a(customer_class)
      expect(customer.email).to eq("john@example.com")
    end

    it "works with where method" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      expect(mock_client).to receive(:execute) do |query, **_variables|
        expect(query).to include("id")
        expect(query).to include("email")
        expect(query).not_to include("displayName")
        { "data" => { "customers" => { "pageInfo" => { "hasNextPage" => false }, "nodes" => [{ "id" => "gid://shopify/Customer/123", "email" => "john@example.com" }] } } }
      end

      customers = customer_class.select(:email).where(first_name: "John").to_a

      expect(customers).to be_an(Array)
      expect(customers.size).to eq(1)
      expect(customers.first.email).to eq("john@example.com")
    end
  end

  describe ".default_loader" do
    it "returns the same instance on multiple calls" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)

      loader1 = customer_class.default_loader
      loader2 = customer_class.default_loader

      expect(loader1).to be(loader2)
    end

    it "automatically includes connections with eager_load: true" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      stub_const("Order", build_order_class)
      customer_class.connection :orders, eager_load: true, default_arguments: { first: 10 }

      loader = customer_class.default_loader

      expect(loader.instance_variable_get(:@included_connections)).to eq([:orders])
    end
  end
end
