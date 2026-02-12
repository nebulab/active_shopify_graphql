# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Configuration do
  describe "#initialize" do
    it "sets admin_api_executor to nil by default" do
      config = described_class.new

      expect(config.admin_api_executor).to be_nil
    end

    it "sets customer_account_api_executor to nil by default" do
      config = described_class.new

      expect(config.customer_account_api_executor).to be_nil
    end

    it "sets logger to nil by default" do
      config = described_class.new

      expect(config.logger).to be_nil
    end

    it "sets log_queries to false by default" do
      config = described_class.new

      expect(config.log_queries).to be false
    end

    it "auto-detects ShopifyApi admin adapter when shopify_api gem is available" do
      stub_const("ShopifyAPI::Clients::Graphql::Admin", Class.new)

      config = described_class.new

      expect(config.admin_api_adapter).to be_a(ActiveShopifyGraphQL::Adapters::ShopifyApiAdmin)
    end

    it "sets customer_account_api_adapter to nil by default even when shopify_api is available" do
      stub_const("ShopifyAPI::Clients::Graphql::Admin", Class.new)

      config = described_class.new

      expect(config.customer_account_api_adapter).to be_nil
    end

    it "sets admin_api_adapter to nil when shopify_api gem is not available" do
      hide_const("ShopifyAPI::Clients::Graphql::Admin") if defined?(ShopifyAPI::Clients::Graphql::Admin)

      config = described_class.new

      expect(config.admin_api_adapter).to be_nil
    end

    it "sets customer_account_api_adapter to nil when shopify_api gem is not available" do
      hide_const("ShopifyAPI::Clients::Graphql::Admin") if defined?(ShopifyAPI::Clients::Graphql::Admin)

      config = described_class.new

      expect(config.customer_account_api_adapter).to be_nil
    end
  end

  describe "attribute accessors" do
    it "allows setting and getting admin_api_executor" do
      config = described_class.new
      custom_executor = ->(query, **variables) { { query: query, variables: variables } }

      config.admin_api_executor = custom_executor

      expect(config.admin_api_executor).to eq(custom_executor)
    end

    it "allows setting and getting customer_account_api_executor" do
      config = described_class.new
      custom_executor = ->(query, token, **variables) { { query: query, token: token, variables: variables } }

      config.customer_account_api_executor = custom_executor

      expect(config.customer_account_api_executor).to eq(custom_executor)
    end

    it "allows setting and getting admin_api_adapter" do
      config = described_class.new
      custom_adapter = ActiveShopifyGraphQL::Adapters::Proc.new(->(query, **variables) { { data: {} } })

      config.admin_api_adapter = custom_adapter

      expect(config.admin_api_adapter).to eq(custom_adapter)
    end

    it "allows setting and getting customer_account_api_adapter" do
      config = described_class.new
      custom_adapter = ActiveShopifyGraphQL::Adapters::Proc.new(->(query, **variables) { { data: {} } })

      config.customer_account_api_adapter = custom_adapter

      expect(config.customer_account_api_adapter).to eq(custom_adapter)
    end

    it "allows setting and getting logger" do
      config = described_class.new
      mock_logger = instance_double(Logger)

      config.logger = mock_logger

      expect(config.logger).to eq(mock_logger)
    end

    it "allows setting and getting log_queries" do
      config = described_class.new

      config.log_queries = true

      expect(config.log_queries).to be true
    end
  end

  describe "#adapter_for" do
    it "returns the admin_api_adapter when explicitly set" do
      config = described_class.new
      custom_adapter = ActiveShopifyGraphQL::Adapters::Proc.new(->(query, **variables) { { data: {} } })
      config.admin_api_adapter = custom_adapter

      adapter = config.adapter_for(:admin_api)

      expect(adapter).to eq(custom_adapter)
    end

    it "returns the customer_account_api_adapter when explicitly set" do
      config = described_class.new
      custom_adapter = ActiveShopifyGraphQL::Adapters::Proc.new(->(query, **variables) { { data: {} } })
      config.customer_account_api_adapter = custom_adapter

      adapter = config.adapter_for(:customer_account_api)

      expect(adapter).to eq(custom_adapter)
    end

    it "wraps admin_api_executor in Proc adapter for backward compatibility" do
      config = described_class.new
      config.admin_api_adapter = nil
      custom_executor = ->(query, **variables) { { data: {} } }
      config.admin_api_executor = custom_executor

      adapter = config.adapter_for(:admin_api)

      expect(adapter).to be_a(ActiveShopifyGraphQL::Adapters::Proc)
      expect(adapter.execute("query", var: "value")).to eq({ data: {} })
    end

    it "wraps customer_account_api_executor in Proc adapter for backward compatibility" do
      config = described_class.new
      config.customer_account_api_adapter = nil
      custom_executor = ->(query, **variables) { { data: {} } }
      config.customer_account_api_executor = custom_executor

      adapter = config.adapter_for(:customer_account_api)

      expect(adapter).to be_a(ActiveShopifyGraphQL::Adapters::Proc)
      expect(adapter.execute("query", var: "value")).to eq({ data: {} })
    end

    it "prefers adapter over executor when both are set" do
      config = described_class.new
      custom_adapter = ActiveShopifyGraphQL::Adapters::Proc.new(->(query, **variables) { { from: "adapter" } })
      custom_executor = ->(query, **variables) { { from: "executor" } }
      config.admin_api_adapter = custom_adapter
      config.admin_api_executor = custom_executor

      adapter = config.adapter_for(:admin_api)

      expect(adapter).to eq(custom_adapter)
      expect(adapter.execute("query")).to eq({ from: "adapter" })
    end

    it "returns nil when neither adapter nor executor is configured" do
      config = described_class.new
      config.admin_api_adapter = nil
      config.admin_api_executor = nil

      adapter = config.adapter_for(:admin_api)

      expect(adapter).to be_nil
    end

    it "raises ArgumentError for unknown API type" do
      config = described_class.new

      expect { config.adapter_for(:unknown_api) }.to raise_error(ArgumentError, "Unknown API type: unknown_api")
    end
  end
end

RSpec.describe ActiveShopifyGraphQL do
  describe ".configuration" do
    it "returns a Configuration instance" do
      config = described_class.configuration

      expect(config).to be_a(ActiveShopifyGraphQL::Configuration)
    end

    it "returns the same instance on multiple calls" do
      config1 = described_class.configuration
      config2 = described_class.configuration

      expect(config1).to be(config2)
    end
  end

  describe ".configure" do
    it "yields the configuration instance" do
      expect { |b| described_class.configure(&b) }.to yield_with_args(ActiveShopifyGraphQL::Configuration)
    end

    it "allows setting configuration values via block" do
      custom_executor = ->(query, **variables) { { query: query, variables: variables } }

      described_class.configure do |config|
        config.admin_api_executor = custom_executor
        config.log_queries = true
      end

      expect(described_class.configuration.admin_api_executor).to eq(custom_executor)
      expect(described_class.configuration.log_queries).to be true
    end

    it "persists configuration across multiple configure calls" do
      custom_executor = ->(query, **variables) { { query: query, variables: variables } }
      mock_logger = instance_double(Logger)

      described_class.configure { |config| config.admin_api_executor = custom_executor }
      described_class.configure { |config| config.logger = mock_logger }

      expect(described_class.configuration.admin_api_executor).to eq(custom_executor)
      expect(described_class.configuration.logger).to eq(mock_logger)
    end
  end

  describe ".reset_configuration!" do
    it "creates a new Configuration instance" do
      old_config = described_class.configuration
      custom_executor = ->(query, **variables) { { query: query, variables: variables } }
      old_config.admin_api_executor = custom_executor

      described_class.reset_configuration!

      new_config = described_class.configuration
      expect(new_config).not_to be(old_config)
      expect(new_config.admin_api_executor).to be_nil
    end

    it "resets all configuration values to defaults" do
      described_class.configure do |config|
        config.log_queries = true
      end

      described_class.reset_configuration!

      expect(described_class.configuration.log_queries).to be false
    end
  end
end
