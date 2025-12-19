# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::SearchQuery::ParameterBinder do
  describe ".bind" do
    context "with positional parameters" do
      it "binds single positional parameter" do
        result = described_class.bind("sku:?", "ABC-123")

        expect(result).to eq("sku:'ABC-123'")
      end

      it "binds multiple positional parameters" do
        result = described_class.bind("sku:? product_id:?", "ABC-123", 456)

        expect(result).to eq("sku:'ABC-123' product_id:456")
      end

      it "escapes quotes in positional parameters" do
        result = described_class.bind("title:?", "Good ol' value with quote")

        expect(result).to eq("title:'Good ol\\' value with quote'")
      end

      it "handles numeric positional parameters" do
        result = described_class.bind("product_id:?", 123)

        expect(result).to eq("product_id:123")
      end

      it "handles boolean positional parameters" do
        result = described_class.bind("published:?", true)

        expect(result).to eq("published:true")
      end

      it "handles nil positional parameters" do
        result = described_class.bind("value:?", nil)

        expect(result).to eq("value:null")
      end

      it "handles mixed types" do
        result = described_class.bind("sku:? product_id:? published:?", "A-SKU", 123, true)

        expect(result).to eq("sku:'A-SKU' product_id:123 published:true")
      end

      it "preserves wildcard syntax when not using placeholders" do
        result = described_class.bind("sku:*")

        expect(result).to eq("sku:*")
      end
    end

    context "with named parameters" do
      it "binds single named parameter" do
        result = described_class.bind("sku::sku", { sku: "ABC-123" })

        expect(result).to eq("sku:'ABC-123'")
      end

      it "binds multiple named parameters" do
        result = described_class.bind("sku::sku product_id::product_id", { sku: "A-SKU", product_id: 123 })

        expect(result).to eq("sku:'A-SKU' product_id:123")
      end

      it "escapes quotes in named parameters" do
        result = described_class.bind("title::title", { title: "Good ol' value with quote" })

        expect(result).to eq("title:'Good ol\\' value with quote'")
      end

      it "handles numeric named parameters" do
        result = described_class.bind("product_id::id", { id: 456 })

        expect(result).to eq("product_id:456")
      end

      it "handles boolean named parameters" do
        result = described_class.bind("published::pub", { pub: false })

        expect(result).to eq("published:false")
      end

      it "handles nil named parameters" do
        result = described_class.bind("value::val", { val: nil })

        expect(result).to eq("value:null")
      end

      it "replaces all occurrences of the same named parameter" do
        result = described_class.bind("(sku::sku OR title::sku)", { sku: "TEST" })

        expect(result).to eq("(sku:'TEST' OR title:'TEST')")
      end

      it "handles parameters in any order" do
        result = described_class.bind("product_id::id sku::sku", { sku: "A-SKU", id: 123 })

        expect(result).to eq("product_id:123 sku:'A-SKU'")
      end
    end

    context "with no parameters" do
      it "returns query string unchanged" do
        result = described_class.bind("sku:*")

        expect(result).to eq("sku:*")
      end
    end

    context "with special characters" do
      it "escapes single quotes" do
        result = described_class.bind("title:?", "O'Reilly")

        expect(result).to eq("title:'O\\'Reilly'")
      end

      it "escapes double quotes" do
        result = described_class.bind("title:?", 'Test "Product"')

        expect(result).to eq("title:'Test \\\"Product\\\"'")
      end

      it "escapes backslashes" do
        result = described_class.bind("path:?", 'C:\\Users\\Documents')

        expect(result).to eq("path:'C:\\Users\\Documents'")
      end

      it "handles complex escaping scenarios" do
        result = described_class.bind("title:?", "John's \"Special\" Product")

        expect(result).to eq("title:'John\\'s \\\"Special\\\" Product'")
      end
    end
  end
end
