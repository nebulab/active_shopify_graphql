# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Response::PaginatedResult do
  describe "#initialize" do
    it "stores attributes, model_class, page_info, and query_scope" do
      test_model_class = build_simple_model_class(name: "TestModel", attributes: %i[id name])
      attributes = [{ id: 1 }, { id: 2 }]
      page_info = ActiveShopifyGraphQL::Response::PageInfo.new("hasNextPage" => true)
      query_scope = double("query_scope")
      paginated_result = ActiveShopifyGraphQL::Response::PaginatedResult.new(
        attributes: attributes,
        model_class: test_model_class,
        page_info: page_info,
        query_scope: query_scope
      )

      expect(paginated_result.records.size).to eq(2)
      expect(paginated_result.records.first).to be_a(test_model_class)
      expect(paginated_result.page_info).to eq(page_info)
      expect(paginated_result.query_scope).to eq(query_scope)
    end
  end

  describe "Enumerable behavior" do
    it "iterates over records" do
      test_model_class = build_simple_model_class(name: "TestModel", attributes: %i[id name])
      attributes = [{ id: 1 }, { id: 2 }]
      page_info = ActiveShopifyGraphQL::Response::PageInfo.new
      paginated_result = ActiveShopifyGraphQL::Response::PaginatedResult.new(
        attributes: attributes,
        model_class: test_model_class,
        page_info: page_info,
        query_scope: nil
      )

      ids = paginated_result.map(&:id)

      expect(ids).to eq([1, 2])
    end

    it "supports map" do
      test_model_class = build_simple_model_class(name: "TestModel", attributes: %i[id name])
      attributes = [{ id: 1 }, { id: 2 }]
      page_info = ActiveShopifyGraphQL::Response::PageInfo.new
      paginated_result = ActiveShopifyGraphQL::Response::PaginatedResult.new(
        attributes: attributes,
        model_class: test_model_class,
        page_info: page_info,
        query_scope: nil
      )

      ids = paginated_result.map(&:id)

      expect(ids).to eq([1, 2])
    end
  end

  describe "#[]" do
    it "provides array-like access to records" do
      test_model_class = build_simple_model_class(name: "TestModel", attributes: %i[id name])
      attributes = [{ id: 1 }, { id: 2 }]
      page_info = ActiveShopifyGraphQL::Response::PageInfo.new
      paginated_result = ActiveShopifyGraphQL::Response::PaginatedResult.new(
        attributes: attributes,
        model_class: test_model_class,
        page_info: page_info,
        query_scope: nil
      )

      expect(paginated_result[0].id).to eq(1)
      expect(paginated_result[1].id).to eq(2)
    end
  end

  describe "#size and #length" do
    it "returns the number of records in this page" do
      test_model_class = build_simple_model_class(name: "TestModel", attributes: %i[id name])
      attributes = [{ id: 1 }, { id: 2 }, { id: 3 }]
      page_info = ActiveShopifyGraphQL::Response::PageInfo.new
      paginated_result = ActiveShopifyGraphQL::Response::PaginatedResult.new(
        attributes: attributes,
        model_class: test_model_class,
        page_info: page_info,
        query_scope: nil
      )

      expect(paginated_result.size).to eq(3)
      expect(paginated_result.length).to eq(3)
    end
  end

  describe "#empty?" do
    it "returns true when no records" do
      test_model_class = build_simple_model_class(name: "TestModel", attributes: %i[id name])
      paginated_result = ActiveShopifyGraphQL::Response::PaginatedResult.new(
        attributes: [],
        model_class: test_model_class,
        page_info: ActiveShopifyGraphQL::Response::PageInfo.new,
        query_scope: nil
      )

      expect(paginated_result.empty?).to be true
    end

    it "returns false when records exist" do
      test_model_class = build_simple_model_class(name: "TestModel", attributes: %i[id name])
      paginated_result = ActiveShopifyGraphQL::Response::PaginatedResult.new(
        attributes: [{ id: 1 }],
        model_class: test_model_class,
        page_info: ActiveShopifyGraphQL::Response::PageInfo.new,
        query_scope: nil
      )

      expect(paginated_result.empty?).to be false
    end
  end

  describe "pagination delegation" do
    it "delegates has_next_page? to page_info" do
      test_model_class = build_simple_model_class(name: "TestModel", attributes: %i[id name])
      page_info = ActiveShopifyGraphQL::Response::PageInfo.new("hasNextPage" => true)
      paginated_result = ActiveShopifyGraphQL::Response::PaginatedResult.new(
        attributes: [],
        model_class: test_model_class,
        page_info: page_info,
        query_scope: nil
      )

      expect(paginated_result.has_next_page?).to be true
    end

    it "delegates has_previous_page? to page_info" do
      test_model_class = build_simple_model_class(name: "TestModel", attributes: %i[id name])
      page_info = ActiveShopifyGraphQL::Response::PageInfo.new("hasPreviousPage" => true)
      paginated_result = ActiveShopifyGraphQL::Response::PaginatedResult.new(
        attributes: [],
        model_class: test_model_class,
        page_info: page_info,
        query_scope: nil
      )

      expect(paginated_result.has_previous_page?).to be true
    end

    it "exposes start_cursor from page_info" do
      test_model_class = build_simple_model_class(name: "TestModel", attributes: %i[id name])
      page_info = ActiveShopifyGraphQL::Response::PageInfo.new("startCursor" => "start123")
      paginated_result = ActiveShopifyGraphQL::Response::PaginatedResult.new(
        attributes: [],
        model_class: test_model_class,
        page_info: page_info,
        query_scope: nil
      )

      expect(paginated_result.start_cursor).to eq("start123")
    end

    it "exposes end_cursor from page_info" do
      test_model_class = build_simple_model_class(name: "TestModel", attributes: %i[id name])
      page_info = ActiveShopifyGraphQL::Response::PageInfo.new("endCursor" => "end456")
      paginated_result = ActiveShopifyGraphQL::Response::PaginatedResult.new(
        attributes: [],
        model_class: test_model_class,
        page_info: page_info,
        query_scope: nil
      )

      expect(paginated_result.end_cursor).to eq("end456")
    end
  end

  describe "#next_page" do
    it "returns nil when no next page exists" do
      test_model_class = build_simple_model_class(name: "TestModel", attributes: %i[id name])
      page_info = ActiveShopifyGraphQL::Response::PageInfo.new("hasNextPage" => false)
      paginated_result = ActiveShopifyGraphQL::Response::PaginatedResult.new(
        attributes: [],
        model_class: test_model_class,
        page_info: page_info,
        query_scope: nil
      )

      expect(paginated_result.next_page).to be_nil
    end

    it "fetches the next page when one exists" do
      test_model_class = build_simple_model_class(name: "TestModel", attributes: %i[id name])
      page_info = ActiveShopifyGraphQL::Response::PageInfo.new(
        "hasNextPage" => true,
        "endCursor" => "cursor123"
      )
      query_scope = instance_double(ActiveShopifyGraphQL::Query::Scope)
      next_page_result = double("next_page")
      paginated_result = ActiveShopifyGraphQL::Response::PaginatedResult.new(
        attributes: [],
        model_class: test_model_class,
        page_info: page_info,
        query_scope: query_scope
      )
      expect(query_scope).to receive(:fetch_page).with(after: "cursor123").and_return(next_page_result)

      result = paginated_result.next_page

      expect(result).to eq(next_page_result)
    end
  end

  describe "#previous_page" do
    it "returns nil when no previous page exists" do
      test_model_class = build_simple_model_class(name: "TestModel", attributes: %i[id name])
      page_info = ActiveShopifyGraphQL::Response::PageInfo.new("hasPreviousPage" => false)
      paginated_result = ActiveShopifyGraphQL::Response::PaginatedResult.new(
        attributes: [],
        model_class: test_model_class,
        page_info: page_info,
        query_scope: nil
      )

      expect(paginated_result.previous_page).to be_nil
    end

    it "fetches the previous page when one exists" do
      test_model_class = build_simple_model_class(name: "TestModel", attributes: %i[id name])
      page_info = ActiveShopifyGraphQL::Response::PageInfo.new(
        "hasPreviousPage" => true,
        "startCursor" => "cursor456"
      )
      query_scope = instance_double(ActiveShopifyGraphQL::Query::Scope)
      previous_page_result = double("previous_page")
      paginated_result = ActiveShopifyGraphQL::Response::PaginatedResult.new(
        attributes: [],
        model_class: test_model_class,
        page_info: page_info,
        query_scope: query_scope
      )
      expect(query_scope).to receive(:fetch_page).with(before: "cursor456").and_return(previous_page_result)

      result = paginated_result.previous_page

      expect(result).to eq(previous_page_result)
    end
  end

  describe "#to_a" do
    it "returns a copy of the records array" do
      test_model_class = build_simple_model_class(name: "TestModel", attributes: %i[id name])
      attributes = [{ id: 1 }, { id: 2 }]
      paginated_result = ActiveShopifyGraphQL::Response::PaginatedResult.new(
        attributes: attributes,
        model_class: test_model_class,
        page_info: ActiveShopifyGraphQL::Response::PageInfo.new,
        query_scope: nil
      )

      result = paginated_result.to_a
      records = paginated_result.records

      expect(result).to eq(records)
      expect(result).not_to be(records)
    end
  end
end
