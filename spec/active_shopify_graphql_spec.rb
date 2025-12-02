# frozen_string_literal: true

RSpec.describe ActiveShopifyGraphQL do
  it "has a version number" do
    expect(ActiveShopifyGraphQL::VERSION).not_to be nil
  end

  it "works correctly" do
    expect(ActiveShopifyGraphQL).to be_a(Module)
  end
end
