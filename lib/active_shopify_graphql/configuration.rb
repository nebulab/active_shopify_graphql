# frozen_string_literal: true

module ActiveShopifyGraphQL
  # Configuration class for setting up external dependencies
  class Configuration
    attr_accessor :admin_api_client, :customer_account_client_class, :logger, :log_queries, :compact_queries

    def initialize
      @admin_api_client = nil
      @customer_account_client_class = nil
      @logger = nil
      @log_queries = false
      @compact_queries = false
    end
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end

  # Reset configuration (useful for testing)
  def self.reset_configuration!
    @configuration = Configuration.new
  end
end
