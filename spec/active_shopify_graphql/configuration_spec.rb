# frozen_string_literal: true

RSpec.describe ActiveShopifyGraphQL::Configuration do
  describe "#initialize" do
    it "sets admin_api_client to nil by default" do
      config = described_class.new

      expect(config.admin_api_client).to be_nil
    end

    it "sets customer_account_client_class to nil by default" do
      config = described_class.new

      expect(config.customer_account_client_class).to be_nil
    end

    it "sets logger to nil by default" do
      config = described_class.new

      expect(config.logger).to be_nil
    end

    it "sets log_queries to false by default" do
      config = described_class.new

      expect(config.log_queries).to be false
    end

    it "sets compact_queries to false by default" do
      config = described_class.new

      expect(config.compact_queries).to be false
    end
  end

  describe "attribute accessors" do
    it "allows setting and getting admin_api_client" do
      config = described_class.new
      mock_client = instance_double("GraphQLClient")

      config.admin_api_client = mock_client

      expect(config.admin_api_client).to eq(mock_client)
    end

    it "allows setting and getting customer_account_client_class" do
      config = described_class.new
      mock_class = Class.new

      config.customer_account_client_class = mock_class

      expect(config.customer_account_client_class).to eq(mock_class)
    end

    it "allows setting and getting logger" do
      config = described_class.new
      mock_logger = instance_double("Logger")

      config.logger = mock_logger

      expect(config.logger).to eq(mock_logger)
    end

    it "allows setting and getting log_queries" do
      config = described_class.new

      config.log_queries = true

      expect(config.log_queries).to be true
    end

    it "allows setting and getting compact_queries" do
      config = described_class.new

      config.compact_queries = true

      expect(config.compact_queries).to be true
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
    after do
      # Reset configuration after each test
      described_class.reset_configuration!
    end

    it "yields the configuration instance" do
      expect { |b| described_class.configure(&b) }.to yield_with_args(ActiveShopifyGraphQL::Configuration)
    end

    it "allows setting configuration values via block" do
      mock_client = instance_double("GraphQLClient")

      described_class.configure do |config|
        config.admin_api_client = mock_client
        config.log_queries = true
      end

      expect(described_class.configuration.admin_api_client).to eq(mock_client)
      expect(described_class.configuration.log_queries).to be true
    end

    it "persists configuration across multiple configure calls" do
      mock_client = instance_double("GraphQLClient")
      mock_logger = instance_double("Logger")

      described_class.configure do |config|
        config.admin_api_client = mock_client
      end

      described_class.configure do |config|
        config.logger = mock_logger
      end

      expect(described_class.configuration.admin_api_client).to eq(mock_client)
      expect(described_class.configuration.logger).to eq(mock_logger)
    end
  end

  describe ".reset_configuration!" do
    it "creates a new Configuration instance" do
      old_config = described_class.configuration
      mock_client = instance_double("GraphQLClient")
      old_config.admin_api_client = mock_client

      described_class.reset_configuration!

      new_config = described_class.configuration
      expect(new_config).not_to be(old_config)
      expect(new_config.admin_api_client).to be_nil
    end

    it "resets all configuration values to defaults" do
      described_class.configure do |config|
        config.admin_api_client = instance_double("GraphQLClient")
        config.log_queries = true
        config.compact_queries = true
      end

      described_class.reset_configuration!

      config = described_class.configuration
      expect(config.admin_api_client).to be_nil
      expect(config.log_queries).to be false
      expect(config.compact_queries).to be false
    end
  end
end
