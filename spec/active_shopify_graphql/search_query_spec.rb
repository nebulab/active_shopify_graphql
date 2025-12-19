# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::SearchQuery do
  describe "#to_s" do
    context "with hash conditions" do
      it "delegates to HashConditionFormatter" do
        conditions = { status: "open" }
        allow(ActiveShopifyGraphQL::SearchQuery::HashConditionFormatter).to receive(:format).and_return("formatted")
        search_query = described_class.new(conditions)

        search_query.to_s

        expect(ActiveShopifyGraphQL::SearchQuery::HashConditionFormatter).to have_received(:format).with(conditions)
      end
    end

    context "with string conditions without parameters" do
      it "returns string as-is without delegation" do
        search_query = described_class.new("sku:*")

        result = search_query.to_s

        expect(result).to eq("sku:*")
      end
    end

    context "with string conditions with parameters" do
      it "delegates to ParameterBinder for positional parameters" do
        allow(ActiveShopifyGraphQL::SearchQuery::ParameterBinder).to receive(:bind).and_return("bound")
        search_query = described_class.new("sku:?", "ABC-123")

        search_query.to_s

        expect(ActiveShopifyGraphQL::SearchQuery::ParameterBinder).to have_received(:bind).with("sku:?", "ABC-123")
      end

      it "delegates to ParameterBinder for named parameters" do
        params = { sku: "TEST" }
        allow(ActiveShopifyGraphQL::SearchQuery::ParameterBinder).to receive(:bind).and_return("bound")
        search_query = described_class.new("sku::sku", params)

        search_query.to_s

        expect(ActiveShopifyGraphQL::SearchQuery::ParameterBinder).to have_received(:bind).with("sku::sku", params)
      end
    end

    context "with array format (from FinderMethods#where)" do
      it "delegates to ParameterBinder with extracted query and args" do
        allow(ActiveShopifyGraphQL::SearchQuery::ParameterBinder).to receive(:bind).and_return("bound")
        search_query = described_class.new(["sku:?", "TEST"])

        search_query.to_s

        expect(ActiveShopifyGraphQL::SearchQuery::ParameterBinder).to have_received(:bind).with("sku:?", "TEST")
      end
    end

    context "with nil or unsupported conditions" do
      it "returns empty string" do
        search_query = described_class.new(nil)

        result = search_query.to_s

        expect(result).to eq("")
      end
    end
  end
end
