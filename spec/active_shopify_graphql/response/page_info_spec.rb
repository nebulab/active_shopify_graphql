# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Response::PageInfo do
  describe "#initialize" do
    it "parses page info data from a hash" do
      data = {
        "hasNextPage" => true,
        "hasPreviousPage" => false,
        "startCursor" => "abc123",
        "endCursor" => "xyz789"
      }
      page_info = described_class.new(data)

      expect(page_info.has_next_page?).to be true
      expect(page_info.has_previous_page?).to be false
      expect(page_info.start_cursor).to eq("abc123")
      expect(page_info.end_cursor).to eq("xyz789")
    end

    it "handles empty data hash" do
      page_info = described_class.new({})

      expect(page_info.has_next_page?).to be false
      expect(page_info.has_previous_page?).to be false
      expect(page_info.start_cursor).to be_nil
      expect(page_info.end_cursor).to be_nil
    end

    it "handles nil data" do
      page_info = described_class.new

      expect(page_info.has_next_page?).to be false
      expect(page_info.has_previous_page?).to be false
    end
  end

  describe "#empty?" do
    it "returns true when no cursors present" do
      page_info = described_class.new({})

      expect(page_info.empty?).to be true
    end

    it "returns false when cursors are present" do
      page_info = described_class.new("startCursor" => "abc")

      expect(page_info.empty?).to be false
    end
  end

  describe "#to_h" do
    it "converts to a hash" do
      data = {
        "hasNextPage" => true,
        "hasPreviousPage" => true,
        "startCursor" => "start",
        "endCursor" => "end"
      }
      page_info = described_class.new(data)

      expect(page_info.to_h).to eq({
                                     has_next_page: true,
                                     has_previous_page: true,
                                     start_cursor: "start",
                                     end_cursor: "end"
                                   })
    end
  end
end
