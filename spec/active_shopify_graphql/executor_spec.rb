# frozen_string_literal: true

RSpec.describe ActiveShopifyGraphQL::Executor do
  describe "#initialize" do
    it "stores the client_type" do
      executor = described_class.new(:admin_api)

      expect(executor.client_type).to eq(:admin_api)
    end
  end

  describe "#execute" do
    after do
      ActiveShopifyGraphQL.reset_configuration!
    end

    context "with admin_api client type" do
      it "executes query via admin API client" do
        mock_client = instance_double("GraphQLClient")
        ActiveShopifyGraphQL.configure do |config|
          config.admin_api_client = mock_client
        end

        executor = described_class.new(:admin_api)
        query = "query { shop { name } }"
        variables = { id: "123" }
        expected_response = { "data" => { "shop" => { "name" => "Test Shop" } } }

        allow(mock_client).to receive(:execute).with(query, id: "123").and_return(expected_response)

        result = executor.execute(query, **variables)

        expect(result).to eq(expected_response)
        expect(mock_client).to have_received(:execute).with(query, id: "123")
      end

      it "raises error when admin API client is not configured" do
        ActiveShopifyGraphQL.configure do |config|
          config.admin_api_client = nil
        end

        executor = described_class.new(:admin_api)
        query = "query { shop { name } }"

        expect { executor.execute(query) }.to raise_error(
          ActiveShopifyGraphQL::Error,
          "Admin API client not configured. Please configure it using ActiveShopifyGraphQL.configure"
        )
      end

      it "executes query without variables" do
        mock_client = instance_double("GraphQLClient")
        ActiveShopifyGraphQL.configure do |config|
          config.admin_api_client = mock_client
        end

        executor = described_class.new(:admin_api)
        query = "query { shop { name } }"
        expected_response = { "data" => { "shop" => { "name" => "Test Shop" } } }

        allow(mock_client).to receive(:execute).with(query).and_return(expected_response)

        result = executor.execute(query)

        expect(result).to eq(expected_response)
      end
    end

    context "with customer_account_api client type" do
      it "raises NotImplementedError" do
        executor = described_class.new(:customer_account_api)
        query = "query { customer { id } }"

        expect { executor.execute(query) }.to raise_error(
          NotImplementedError,
          "Customer Account API support needs token handling implementation"
        )
      end
    end

    context "with unknown client type" do
      it "raises ArgumentError" do
        executor = described_class.new(:unknown_type)
        query = "query { shop { name } }"

        expect { executor.execute(query) }.to raise_error(
          ArgumentError,
          "Unknown client type: unknown_type"
        )
      end
    end

    context "with query logging enabled" do
      it "logs query and variables when log_queries is true and logger is configured" do
        mock_client = instance_double("GraphQLClient")
        mock_logger = instance_double("Logger")
        ActiveShopifyGraphQL.configure do |config|
          config.admin_api_client = mock_client
          config.logger = mock_logger
          config.log_queries = true
        end

        executor = described_class.new(:admin_api)
        query = "query { shop { name } }"
        variables = { id: "123" }

        allow(mock_client).to receive(:execute).and_return({ "data" => {} })
        allow(mock_logger).to receive(:info)

        executor.execute(query, **variables)

        expect(mock_logger).to have_received(:info).with("ActiveShopifyGraphQL Query:\n#{query}")
        expect(mock_logger).to have_received(:info).with("ActiveShopifyGraphQL Variables:\n#{variables}")
      end

      it "does not log when log_queries is false" do
        mock_client = instance_double("GraphQLClient")
        mock_logger = instance_double("Logger")
        ActiveShopifyGraphQL.configure do |config|
          config.admin_api_client = mock_client
          config.logger = mock_logger
          config.log_queries = false
        end

        executor = described_class.new(:admin_api)
        query = "query { shop { name } }"

        allow(mock_client).to receive(:execute).and_return({ "data" => {} })
        allow(mock_logger).to receive(:info)

        executor.execute(query)

        expect(mock_logger).not_to have_received(:info)
      end

      it "does not log when logger is not configured" do
        mock_client = instance_double("GraphQLClient")
        ActiveShopifyGraphQL.configure do |config|
          config.admin_api_client = mock_client
          config.logger = nil
          config.log_queries = true
        end

        executor = described_class.new(:admin_api)
        query = "query { shop { name } }"

        allow(mock_client).to receive(:execute).and_return({ "data" => {} })

        expect { executor.execute(query) }.not_to raise_error
      end
    end
  end
end
