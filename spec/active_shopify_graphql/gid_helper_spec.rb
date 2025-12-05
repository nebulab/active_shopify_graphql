# frozen_string_literal: true

RSpec.describe ActiveShopifyGraphQL::GidHelper do
  describe ".normalize_gid" do
    it "returns existing valid GID as-is" do
      gid = "gid://shopify/Customer/123"
      result = described_class.normalize_gid(gid, "Customer")

      expect(result).to eq(gid)
    end

    it "builds GID from numeric ID" do
      result = described_class.normalize_gid(123, "Customer")

      expect(result).to eq("gid://shopify/Customer/123")
    end

    it "builds GID from string numeric ID" do
      result = described_class.normalize_gid("456", "Order")

      expect(result).to eq("gid://shopify/Order/456")
    end

    it "builds GID from large numeric ID" do
      result = described_class.normalize_gid(7_285_147_926_827, "Customer")

      expect(result).to eq("gid://shopify/Customer/7285147926827")
    end

    it "handles invalid GID string by building new GID" do
      result = described_class.normalize_gid("not-a-gid", "Customer")

      expect(result).to eq("gid://shopify/Customer/not-a-gid")
    end

    it "preserves GID with different app" do
      # This is a non-Shopify GID, but still valid URI::GID format
      gid = "gid://other-app/Customer/123"
      result = described_class.normalize_gid(gid, "Customer")

      # It should be preserved as-is because it's a valid GID
      expect(result).to eq(gid)
    end

    it "uses provided model_name when building GID" do
      result = described_class.normalize_gid(789, "ProductVariant")

      expect(result).to eq("gid://shopify/ProductVariant/789")
    end
  end

  describe ".valid_gid?" do
    it "returns true for valid Shopify GID" do
      expect(described_class.valid_gid?("gid://shopify/Customer/123")).to be true
    end

    it "returns true for valid GID with different app" do
      expect(described_class.valid_gid?("gid://other/Customer/123")).to be true
    end

    it "returns false for numeric ID" do
      expect(described_class.valid_gid?(123)).to be false
    end

    it "returns false for string numeric ID" do
      expect(described_class.valid_gid?("123")).to be false
    end

    it "returns false for invalid GID format" do
      expect(described_class.valid_gid?("not-a-gid")).to be false
    end

    it "returns false for empty string" do
      expect(described_class.valid_gid?("")).to be false
    end

    it "returns false for nil" do
      expect(described_class.valid_gid?(nil)).to be false
    end
  end
end
