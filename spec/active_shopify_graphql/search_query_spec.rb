# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::SearchQuery do
  describe "#to_s" do
    it "formats string conditions" do
      search_query = described_class.new(status: "open")

      expect(search_query.to_s).to eq("status:open")
    end

    it "formats numeric conditions" do
      search_query = described_class.new(total_price: 100)

      expect(search_query.to_s).to eq("total_price:100")
    end

    it "formats boolean conditions" do
      search_query = described_class.new(published: true)

      expect(search_query.to_s).to eq("published:true")
    end

    it "quotes multi-word string values" do
      search_query = described_class.new(name: "John Doe")

      expect(search_query.to_s).to eq('name:"John Doe"')
    end

    it "escapes quotes in string values" do
      search_query = described_class.new(title: 'Test "Product"')

      expect(search_query.to_s).to eq('title:"Test \"Product\""')
    end

    it "formats range conditions with gte" do
      search_query = described_class.new(created_at: { gte: "2024-01-01" })

      expect(search_query.to_s).to eq("created_at:>=2024-01-01")
    end

    it "formats range conditions with multiple operators" do
      search_query = described_class.new(created_at: { gte: "2024-01-01", lte: "2024-12-31" })

      result = search_query.to_s

      expect(result).to include("created_at:>=2024-01-01")
      expect(result).to include("created_at:<=2024-12-31")
    end

    it "supports symbol range operators" do
      search_query = described_class.new(created_at: { '>': "2024-01-01" })

      expect(search_query.to_s).to eq("created_at:>2024-01-01")
    end

    it "combines multiple conditions with AND" do
      search_query = described_class.new(status: "open", fulfillment_status: "unfulfilled")

      expect(search_query.to_s).to eq("status:open AND fulfillment_status:unfulfilled")
    end

    it "returns empty string for empty conditions" do
      search_query = described_class.new({})

      expect(search_query.to_s).to eq("")
    end

    it "raises error for unsupported range operators" do
      search_query = described_class.new(created_at: { invalid: "2024-01-01" })

      expect { search_query.to_s }.to raise_error(ArgumentError, /Unsupported range operator/)
    end

    it "formats array with single numeric value as simple condition" do
      search_query = described_class.new(id: [1])

      expect(search_query.to_s).to eq("id:1")
    end

    it "formats array with multiple numeric values as OR clause" do
      search_query = described_class.new(id: [1, 2, 3])

      expect(search_query.to_s).to eq("(id:1 OR id:2 OR id:3)")
    end

    it "formats array with string values as OR clause" do
      search_query = described_class.new(status: %w[open pending])

      expect(search_query.to_s).to eq("(status:open OR status:pending)")
    end

    it "formats array with multi-word strings with proper quoting" do
      search_query = described_class.new(title: ["Product One", "Product Two"])

      expect(search_query.to_s).to eq('(title:"Product One" OR title:"Product Two")')
    end

    it "formats multiple fields with array values using AND between groups" do
      search_query = described_class.new(id: [1, 2, 3], status: %w[open pending])

      result = search_query.to_s

      expect(result).to include("(id:1 OR id:2 OR id:3)")
      expect(result).to include("(status:open OR status:pending)")
      expect(result).to include(" AND ")
    end

    it "mixes array and non-array conditions correctly" do
      search_query = described_class.new(id: [1, 2, 3], title: "foo")

      result = search_query.to_s

      expect(result).to eq("(id:1 OR id:2 OR id:3) AND title:foo")
    end

    it "handles empty array by returning empty string for that condition" do
      search_query = described_class.new(id: [])

      expect(search_query.to_s).to eq("")
    end

    it "formats arrays with boolean values" do
      search_query = described_class.new(published: [true, false])

      expect(search_query.to_s).to eq("(published:true OR published:false)")
    end
  end
end
