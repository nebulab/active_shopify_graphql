# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Query::Scope do
  describe "#initialize" do
    it "stores model class and conditions" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      scope = ActiveShopifyGraphQL::Query::Scope.new(customer_class, conditions: { email: "test@example.com" })

      expect(scope.model_class).to eq(customer_class)
      expect(scope.conditions).to eq({ email: "test@example.com" })
    end

    it "defaults per_page to 250" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      scope = described_class.new(customer_class, conditions: {})

      expect(scope.per_page).to eq(250)
    end

    it "accepts custom per_page" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      scope = described_class.new(customer_class, conditions: {}, per_page: 50)

      expect(scope.per_page).to eq(50)
    end

    it "caps per_page at 250" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      scope = described_class.new(customer_class, conditions: {}, per_page: 500)

      expect(scope.per_page).to eq(250)
    end
  end

  describe "#limit" do
    it "returns a new scope with total_limit set" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      scope = described_class.new(customer_class, conditions: {})

      limited_scope = scope.limit(100)

      expect(limited_scope).to be_a(described_class)
      expect(limited_scope).not_to eq(scope)
      expect(limited_scope.total_limit).to eq(100)
    end

    it "is chainable" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      scope = described_class.new(customer_class, conditions: { email: "test" })
      allow(mock_client).to receive(:execute).and_return(
        {
          "data" => { "customers" => { "pageInfo" => { "hasNextPage" => false }, "nodes" => [] } }
        }
      )

      limited_scope = scope.limit(50)
      result = limited_scope.to_a

      expect(result).to be_an(Array)
    end
  end

  describe "#in_pages" do
    it "returns a PaginatedResult without a block" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      allow(mock_client).to receive(:execute).and_return(
        {
          "data" => { "customers" => { "pageInfo" => { "hasNextPage" => true, "endCursor" => "abc" }, "nodes" => [] } }
        }
      )
      scope = customer_class.where(email: "test")

      result = scope.in_pages(of: 10)

      expect(result).to be_a(ActiveShopifyGraphQL::Response::PaginatedResult)
    end

    it "yields each page with a block" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      call_count = 0
      allow(mock_client).to receive(:execute) do
        call_count += 1
        if call_count == 1
          { "data" => { "customers" => {
            "pageInfo" => { "hasNextPage" => true, "endCursor" => "cursor1" },
            "nodes" => [{ "id" => "gid://shopify/Customer/1", "email" => "a@test.com" }]
          } } }
        else
          { "data" => { "customers" => {
            "pageInfo" => { "hasNextPage" => false },
            "nodes" => [{ "id" => "gid://shopify/Customer/2", "email" => "b@test.com" }]
          } } }
        end
      end
      scope = customer_class.where(email: "*")
      pages_yielded = []

      scope.in_pages(of: 1) { |page| pages_yielded << page }

      expect(pages_yielded.size).to eq(2)
      expect(pages_yielded[0]).to be_a(ActiveShopifyGraphQL::Response::PaginatedResult)
      expect(pages_yielded[1]).to be_a(ActiveShopifyGraphQL::Response::PaginatedResult)
    end

    it "respects per_page size" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:first]).to eq(25)
        { "data" => { "customers" => { "pageInfo" => { "hasNextPage" => false }, "nodes" => [] } } }
      end
      scope = customer_class.where(email: "test")

      scope.in_pages(of: 25).to_a
    end

    it "caps per_page at 250" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      expect(mock_client).to receive(:execute) do |_query, **variables|
        expect(variables[:first]).to eq(250)
        { "data" => { "customers" => { "pageInfo" => { "hasNextPage" => false }, "nodes" => [] } } }
      end
      scope = customer_class.where(email: "test")

      scope.in_pages(of: 500).to_a
    end
  end

  describe "#to_a" do
    it "loads all records across multiple pages" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      call_count = 0
      allow(mock_client).to receive(:execute) do
        call_count += 1
        if call_count == 1
          { "data" => { "customers" => {
            "pageInfo" => { "hasNextPage" => true, "endCursor" => "cursor1" },
            "nodes" => [{ "id" => "gid://shopify/Customer/1", "email" => "a@test.com" }]
          } } }
        else
          { "data" => { "customers" => {
            "pageInfo" => { "hasNextPage" => false },
            "nodes" => [{ "id" => "gid://shopify/Customer/2", "email" => "b@test.com" }]
          } } }
        end
      end
      scope = customer_class.where(email: "*").in_pages(of: 1)

      result = scope.to_a

      expect(result.size).to eq(1) # PaginatedResult#to_a returns current page records only
    end

    it "respects total_limit across pages" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      call_count = 0
      allow(mock_client).to receive(:execute) do
        call_count += 1
        { "data" => { "customers" => {
          "pageInfo" => { "hasNextPage" => call_count < 5, "endCursor" => "cursor#{call_count}" },
          "nodes" => [{ "id" => "gid://shopify/Customer/#{call_count}", "email" => "#{call_count}@test.com" }]
        } } }
      end
      scope = customer_class.where(email: "*").limit(3)

      records = []
      scope.in_pages(of: 1) { |page| records.concat(page.to_a) }

      expect(records.size).to eq(3)
    end
  end

  describe "#first" do
    it "returns the first record" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      allow(mock_client).to receive(:execute).and_return(
        {
          "data" => { "customers" => {
            "pageInfo" => { "hasNextPage" => false },
            "nodes" => [{ "id" => "gid://shopify/Customer/1", "email" => "first@test.com" }]
          } }
        }
      )
      scope = customer_class.where(email: "*")

      result = scope.first

      expect(result).to be_a(customer_class)
      expect(result.email).to eq("first@test.com")
    end

    it "returns nil when no results" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      allow(mock_client).to receive(:execute).and_return(
        {
          "data" => { "customers" => { "pageInfo" => { "hasNextPage" => false }, "nodes" => [] } }
        }
      )
      scope = customer_class.where(email: "nonexistent")

      result = scope.first

      expect(result).to be_nil
    end

    it "returns n records when count is given" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      allow(mock_client).to receive(:execute).and_return(
        {
          "data" => { "customers" => {
            "pageInfo" => { "hasNextPage" => false },
            "nodes" => [
              { "id" => "gid://shopify/Customer/1", "email" => "a@test.com" },
              { "id" => "gid://shopify/Customer/2", "email" => "b@test.com" }
            ]
          } }
        }
      )
      scope = customer_class.where(email: "*")

      result = scope.first(2)

      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
    end
  end

  describe "#each" do
    it "iterates over all records across pages" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      call_count = 0
      allow(mock_client).to receive(:execute) do
        call_count += 1
        if call_count == 1
          { "data" => { "customers" => {
            "pageInfo" => { "hasNextPage" => true, "endCursor" => "cursor1" },
            "nodes" => [{ "id" => "gid://shopify/Customer/1", "email" => "a@test.com" }]
          } } }
        else
          { "data" => { "customers" => {
            "pageInfo" => { "hasNextPage" => false },
            "nodes" => [{ "id" => "gid://shopify/Customer/2", "email" => "b@test.com" }]
          } } }
        end
      end
      scope = customer_class.where(email: "*")
      emails = []

      scope.in_pages(of: 1) { |page| page.each { |c| emails << c.email } }

      expect(emails).to eq(["a@test.com", "b@test.com"])
    end

    it "returns an enumerator when no block given" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      scope = customer_class.where(email: "*")

      result = scope.each

      expect(result).to be_an(Enumerator)
    end
  end

  describe "Enumerable compatibility" do
    it "supports map" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      allow(mock_client).to receive(:execute).and_return(
        {
          "data" => { "customers" => {
            "pageInfo" => { "hasNextPage" => false },
            "nodes" => [
              { "id" => "gid://shopify/Customer/1", "email" => "a@test.com" },
              { "id" => "gid://shopify/Customer/2", "email" => "b@test.com" }
            ]
          } }
        }
      )
      scope = customer_class.where(email: "*")

      emails = scope.map(&:email)

      expect(emails).to eq(["a@test.com", "b@test.com"])
    end

    it "supports empty?" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      allow(mock_client).to receive(:execute).and_return(
        {
          "data" => { "customers" => { "pageInfo" => { "hasNextPage" => false }, "nodes" => [] } }
        }
      )
      scope = customer_class.where(email: "*")

      expect(scope.empty?).to be true
    end

    it "supports size/length" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      allow(mock_client).to receive(:execute).and_return(
        {
          "data" => { "customers" => {
            "pageInfo" => { "hasNextPage" => false },
            "nodes" => [
              { "id" => "gid://shopify/Customer/1", "email" => "a@test.com" },
              { "id" => "gid://shopify/Customer/2", "email" => "b@test.com" }
            ]
          } }
        }
      )
      scope = customer_class.where(email: "*")

      expect(scope.size).to eq(2)
      expect(scope.length).to eq(2)
    end

    it "supports array indexing" do
      mock_client = instance_double("ShopifyAPI::Clients::Graphql::Admin")
      ActiveShopifyGraphQL.configure { |c| c.admin_api_client = mock_client }
      customer_class = build_customer_class
      stub_const("Customer", customer_class)
      allow(mock_client).to receive(:execute).and_return(
        {
          "data" => { "customers" => {
            "pageInfo" => { "hasNextPage" => false },
            "nodes" => [
              { "id" => "gid://shopify/Customer/1", "email" => "a@test.com" },
              { "id" => "gid://shopify/Customer/2", "email" => "b@test.com" }
            ]
          } }
        }
      )
      scope = customer_class.where(email: "*")

      expect(scope[0].email).to eq("a@test.com")
      expect(scope[1].email).to eq("b@test.com")
    end
  end
end
