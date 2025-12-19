# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::SearchQuery::HashConditionFormatter do
  describe ".format" do
    it "formats string conditions with proper escaping" do
      result = described_class.format(status: "open")

      expect(result).to eq("status:'open'")
    end

    it "formats numeric conditions" do
      result = described_class.format(total_price: 100)

      expect(result).to eq("total_price:100")
    end

    it "formats boolean conditions" do
      result = described_class.format(published: true)

      expect(result).to eq("published:true")
    end

    it "quotes multi-word string values" do
      result = described_class.format(name: "John Doe")

      expect(result).to eq("name:'John Doe'")
    end

    it "escapes quotes in string values" do
      result = described_class.format(title: 'Test "Product"')

      expect(result).to eq("title:'Test \\\"Product\\\"'")
    end

    it "escapes single quotes in string values" do
      result = described_class.format(title: "O'Reilly")

      expect(result).to eq("title:'O\\\\'Reilly'")
    end

    it "formats range conditions with gte" do
      result = described_class.format(created_at: { gte: "2024-01-01" })

      expect(result).to eq("created_at:>=2024-01-01")
    end

    it "formats range conditions with multiple operators" do
      result = described_class.format(created_at: { gte: "2024-01-01", lte: "2024-12-31" })

      expect(result).to include("created_at:>=2024-01-01")
      expect(result).to include("created_at:<=2024-12-31")
    end

    it "supports symbol range operators" do
      result = described_class.format(created_at: { '>': "2024-01-01" })

      expect(result).to eq("created_at:>2024-01-01")
    end

    it "combines multiple conditions with AND" do
      result = described_class.format(status: "open", fulfillment_status: "unfulfilled")

      expect(result).to eq("status:'open' AND fulfillment_status:'unfulfilled'")
    end

    it "returns empty string for empty conditions" do
      result = described_class.format({})

      expect(result).to eq("")
    end

    it "raises error for unsupported range operators" do
      expect { described_class.format(created_at: { invalid: "2024-01-01" }) }
        .to raise_error(ArgumentError, /Unsupported range operator/)
    end

    it "formats array with single numeric value as simple condition" do
      result = described_class.format(id: [1])

      expect(result).to eq("id:1")
    end

    it "formats array with multiple numeric values as OR clause" do
      result = described_class.format(id: [1, 2, 3])

      expect(result).to eq("(id:1 OR id:2 OR id:3)")
    end

    it "formats array with string values as OR clause" do
      result = described_class.format(status: %w[open pending])

      expect(result).to eq("(status:'open' OR status:'pending')")
    end

    it "formats array with multi-word strings with proper quoting" do
      result = described_class.format(title: ["Product One", "Product Two"])

      expect(result).to eq("(title:'Product One' OR title:'Product Two')")
    end

    it "formats multiple fields with array values using AND between groups" do
      result = described_class.format(id: [1, 2, 3], status: %w[open pending])

      expect(result).to include("(id:1 OR id:2 OR id:3)")
      expect(result).to include("(status:'open' OR status:'pending')")
      expect(result).to include(" AND ")
    end

    it "mixes array and non-array conditions correctly" do
      result = described_class.format(id: [1, 2, 3], title: "foo")

      expect(result).to eq("(id:1 OR id:2 OR id:3) AND title:'foo'")
    end

    it "handles empty array by returning empty string for that condition" do
      result = described_class.format(id: [])

      expect(result).to eq("")
    end

    it "formats arrays with boolean values" do
      result = described_class.format(published: [true, false])

      expect(result).to eq("(published:true OR published:false)")
    end

    it "escapes quotes in array values" do
      result = described_class.format(email: ['"Dave"', '"Jane"'])

      expect(result).to eq("(email:'\\\"Dave\\\"' OR email:'\\\"Jane\\\"')")
    end

    it "escapes single quotes in array values" do
      result = described_class.format(title: ["O'Reilly", "McDonald's"])

      expect(result).to eq("(title:'O\\\\'Reilly' OR title:'McDonald\\\\'s')")
    end

    it "escapes backslashes" do
      result = described_class.format(path: 'C:\\Users\\Documents')

      expect(result).to eq("path:'C:\\\\Users\\\\Documents'")
    end

    it "escapes wildcards in hash conditions (no raw wildcard matching)" do
      result = described_class.format(sku: "*")

      expect(result).to eq("sku:'*'")
    end
  end
end
