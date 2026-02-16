# frozen_string_literal: true

# Simulates a base controller with the methods the concern expects
module BaseControllerBehavior
  extend ActiveSupport::Concern

  module ClassMethods
    def log_process_action(_payload)
      []
    end
  end

  def append_info_to_payload(_payload)
    # Base implementation does nothing
  end
end

RSpec.describe ActiveShopifyGraphQL::Logging::GraphqlControllerRuntime do
  let(:controller_class) do
    Class.new do
      include BaseControllerBehavior
      include ActiveShopifyGraphQL::Logging::GraphqlControllerRuntime
    end
  end

  after do
    ActiveShopifyGraphQL::Logging::GraphqlRuntime.reset_runtime
    ActiveShopifyGraphQL::Logging::GraphqlRuntime.reset_cost
  end

  describe ".log_process_action" do
    it "adds GraphQL timing when runtime is present" do
      payload = { graphql_runtime: 45.2, graphql_cost: 38 }
      messages = controller_class.log_process_action(payload)
      expect(messages).to eq(["GraphQL: 45.2ms, 38 cost"])
    end

    it "omits cost when zero" do
      payload = { graphql_runtime: 30.5, graphql_cost: 0 }
      messages = controller_class.log_process_action(payload)
      expect(messages).to eq(["GraphQL: 30.5ms"])
    end

    it "adds nothing when runtime is zero" do
      payload = { graphql_runtime: 0, graphql_cost: 0 }
      messages = controller_class.log_process_action(payload)
      expect(messages).to be_empty
    end

    it "adds nothing when runtime is nil" do
      payload = { graphql_runtime: nil, graphql_cost: nil }
      messages = controller_class.log_process_action(payload)
      expect(messages).to be_empty
    end
  end

  describe "#append_info_to_payload" do
    it "resets runtime and cost after appending to payload" do
      ActiveShopifyGraphQL::Logging::GraphqlRuntime.runtime = 50.0
      ActiveShopifyGraphQL::Logging::GraphqlRuntime.cost = 25

      payload = {}
      controller_class.new.send(:append_info_to_payload, payload)

      expect(payload[:graphql_runtime]).to eq(50.0)
      expect(payload[:graphql_cost]).to eq(25)
      expect(ActiveShopifyGraphQL::Logging::GraphqlRuntime.runtime).to eq(0)
      expect(ActiveShopifyGraphQL::Logging::GraphqlRuntime.cost).to eq(0)
    end
  end
end
