# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::SearchQuery::ValueSanitizer do
  describe ".sanitize" do
    it "escapes double quotes" do
      result = described_class.sanitize('Test "Product"')

      expect(result).to eq('Test \"Product\"')
    end

    it "escapes single quotes" do
      result = described_class.sanitize("O'Reilly")

      expect(result).to eq("O\\\\'Reilly")
    end

    it "escapes both single and double quotes" do
      result = described_class.sanitize("John's \"Special\" Product")

      expect(result).to eq("John\\\\'s \\\"Special\\\" Product")
    end

    it "escapes multiple single quotes" do
      result = described_class.sanitize("'Tis the season for 'giving'")

      expect(result).to eq("\\\\'Tis the season for \\\\'giving\\\\'")
    end

    it "escapes backslashes" do
      result = described_class.sanitize('C:\\Users\\Documents')

      expect(result).to eq('C:\\\\Users\\\\Documents')
    end

    it "escapes backslashes before quotes" do
      result = described_class.sanitize('\\"test\\"')

      expect(result).to eq('\\\\\"test\\\\\"')
    end

    it "handles mixed backslashes and single quotes" do
      result = described_class.sanitize("C:\\John's Folder")

      expect(result).to eq("C:\\\\John\\\\'s Folder")
    end

    it "does not escape wildcards" do
      result = described_class.sanitize("*")

      expect(result).to eq("*")
    end

    it "handles empty strings" do
      result = described_class.sanitize("")

      expect(result).to eq("")
    end

    it "preserves whitespace" do
      result = described_class.sanitize("  test  ")

      expect(result).to eq("  test  ")
    end
  end
end
