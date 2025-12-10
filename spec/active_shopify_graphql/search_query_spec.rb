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
  end
end
