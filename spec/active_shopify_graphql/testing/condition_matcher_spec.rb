# frozen_string_literal: true

require "spec_helper"
require "active_shopify_graphql/testing"

RSpec.describe ActiveShopifyGraphQL::Testing::ConditionMatcher do
  described_class = ActiveShopifyGraphQL::Testing::ConditionMatcher

  describe ".filter" do
    it "filters records matching all conditions" do
      records = [
        { email: "a@test.com", status: "active" },
        { email: "b@test.com", status: "inactive" },
        { email: "c@test.com", status: "active" }
      ]

      results = described_class.filter(records, { status: "active" })

      expect(results.size).to eq(2)
      expect(results.map { |r| r[:email] }).to contain_exactly("a@test.com", "c@test.com")
    end

    it "requires all conditions to match (AND semantics)" do
      records = [
        { email: "a@test.com", status: "active", tier: "gold" },
        { email: "b@test.com", status: "active", tier: "silver" },
        { email: "c@test.com", status: "inactive", tier: "gold" }
      ]

      results = described_class.filter(records, { status: "active", tier: "gold" })

      expect(results.size).to eq(1)
      expect(results.first[:email]).to eq("a@test.com")
    end

    it "returns all records when conditions are empty" do
      records = [{ email: "a@test.com" }, { email: "b@test.com" }]

      results = described_class.filter(records, {})

      expect(results).to eq(records)
    end

    it "returns all records when conditions are nil" do
      records = [{ email: "a@test.com" }, { email: "b@test.com" }]

      results = described_class.filter(records, nil)

      expect(results).to eq(records)
    end
  end

  describe ".matches?" do
    describe "equality matching" do
      it "matches equal string values" do
        record = { email: "test@example.com" }

        expect(described_class.matches?(record, { email: "test@example.com" })).to be(true)
        expect(described_class.matches?(record, { email: "other@example.com" })).to be(false)
      end

      it "matches equal numeric values" do
        record = { quantity: 5 }

        expect(described_class.matches?(record, { quantity: 5 })).to be(true)
        expect(described_class.matches?(record, { quantity: 10 })).to be(false)
      end

      it "matches boolean values" do
        record = { active: true }

        expect(described_class.matches?(record, { active: true })).to be(true)
        expect(described_class.matches?(record, { active: false })).to be(false)
      end

      it "matches nil values" do
        record = { email: nil }

        expect(described_class.matches?(record, { email: nil })).to be(true)
      end

      it "handles string vs symbol key differences" do
        record = { email: "test@example.com" }

        expect(described_class.matches?(record, { "email" => "test@example.com" })).to be(true)
      end

      it "coerces types for comparison when needed" do
        record = { id: "123" }

        expect(described_class.matches?(record, { id: 123 })).to be(true)
      end
    end

    describe "array matching (OR semantics)" do
      it "matches if value is in the array" do
        record = { status: "active" }

        expect(described_class.matches?(record, { status: %w[active pending] })).to be(true)
        expect(described_class.matches?(record, { status: %w[inactive pending] })).to be(false)
      end

      it "matches numeric values in array" do
        record = { tier: 2 }

        expect(described_class.matches?(record, { tier: [1, 2, 3] })).to be(true)
        expect(described_class.matches?(record, { tier: [4, 5, 6] })).to be(false)
      end
    end

    describe "range operator matching" do
      it "matches greater than with :gt" do
        record = { amount: 100 }

        expect(described_class.matches?(record, { amount: { gt: 50 } })).to be(true)
        expect(described_class.matches?(record, { amount: { gt: 100 } })).to be(false)
        expect(described_class.matches?(record, { amount: { gt: 150 } })).to be(false)
      end

      it "matches greater than with :> symbol" do
        record = { amount: 100 }

        expect(described_class.matches?(record, { amount: { :> => 50 } })).to be(true)
      end

      it "matches greater than or equal with :gte" do
        record = { amount: 100 }

        expect(described_class.matches?(record, { amount: { gte: 100 } })).to be(true)
        expect(described_class.matches?(record, { amount: { gte: 50 } })).to be(true)
        expect(described_class.matches?(record, { amount: { gte: 150 } })).to be(false)
      end

      it "matches greater than or equal with :>= symbol" do
        record = { amount: 100 }

        expect(described_class.matches?(record, { amount: { :>= => 100 } })).to be(true)
      end

      it "matches less than with :lt" do
        record = { amount: 100 }

        expect(described_class.matches?(record, { amount: { lt: 150 } })).to be(true)
        expect(described_class.matches?(record, { amount: { lt: 100 } })).to be(false)
        expect(described_class.matches?(record, { amount: { lt: 50 } })).to be(false)
      end

      it "matches less than with :< symbol" do
        record = { amount: 100 }

        expect(described_class.matches?(record, { amount: { :< => 150 } })).to be(true)
      end

      it "matches less than or equal with :lte" do
        record = { amount: 100 }

        expect(described_class.matches?(record, { amount: { lte: 100 } })).to be(true)
        expect(described_class.matches?(record, { amount: { lte: 150 } })).to be(true)
        expect(described_class.matches?(record, { amount: { lte: 50 } })).to be(false)
      end

      it "matches less than or equal with :<= symbol" do
        record = { amount: 100 }

        expect(described_class.matches?(record, { amount: { :<= => 100 } })).to be(true)
      end

      it "combines multiple range operators" do
        record = { amount: 100 }

        expect(described_class.matches?(record, { amount: { gte: 50, lte: 150 } })).to be(true)
        expect(described_class.matches?(record, { amount: { gte: 50, lte: 75 } })).to be(false)
      end

      it "compares string dates as times" do
        record = { created_at: "2024-06-15" }

        expect(described_class.matches?(record, { created_at: { gte: "2024-01-01" } })).to be(true)
        expect(described_class.matches?(record, { created_at: { gte: "2024-12-01" } })).to be(false)
      end

      it "returns false when actual value is nil" do
        record = { amount: nil }

        expect(described_class.matches?(record, { amount: { gt: 50 } })).to be(false)
      end

      it "raises on unsupported operator" do
        record = { amount: 100 }

        expect { described_class.matches?(record, { amount: { like: "%" } }) }
          .to raise_error(ArgumentError, /Unsupported range operator/)
      end
    end
  end
end
