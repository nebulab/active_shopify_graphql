# frozen_string_literal: true

RSpec.describe ActiveShopifyGraphQL::Connections::ConnectionProxy do
  # Create test model classes
  let(:customer_class) do
    Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type 'Customer'

      attribute :id
      attribute :name

      connection :orders, default_arguments: { first: 10 }

      def self.name
        'Customer'
      end

      def self.model_name
        ActiveModel::Name.new(self, nil, 'Customer')
      end

      def self.default_loader_class
        ActiveShopifyGraphQL::AdminApiLoader
      end
    end
  end

  let(:order_class) do
    Class.new do
      include ActiveShopifyGraphQL::Base

      graphql_type 'Order'

      attribute :id
      attribute :name
      attribute :total

      def self.name
        'Order'
      end

      def self.model_name
        ActiveModel::Name.new(self, nil, 'Order')
      end
    end
  end

  let(:parent) { customer_class.new(id: 'gid://shopify/Customer/123', name: 'Test Customer') }
  let(:connection_name) { :orders }
  let(:connection_config) do
    {
      class_name: 'Order',
      query_name: 'orders',
      foreign_key: 'customer_id',
      loader_class: nil,
      default_arguments: { first: 10 }
    }
  end
  let(:options) { {} }
  let(:mock_loader) { instance_double(ActiveShopifyGraphQL::AdminApiLoader) }
  let(:mock_orders) do
    [
      order_class.new(id: 'gid://shopify/Order/1', name: '#1001', total: '100.00'),
      order_class.new(id: 'gid://shopify/Order/2', name: '#1002', total: '200.00'),
      order_class.new(id: 'gid://shopify/Order/3', name: '#1003', total: '300.00')
    ]
  end

  before do
    stub_const('Customer', customer_class)
    stub_const('Order', order_class)

    allow(customer_class).to receive(:default_loader).and_return(mock_loader)
    allow(mock_loader).to receive(:class).and_return(ActiveShopifyGraphQL::AdminApiLoader)
    allow(ActiveShopifyGraphQL::AdminApiLoader).to receive(:new).and_return(mock_loader)
  end

  describe '#initialize' do
    it 'creates a new ConnectionProxy with required parameters' do
      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      expect(proxy).to be_a(described_class)
      expect(proxy.loaded?).to be false
    end

    it 'includes Enumerable module' do
      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      expect(proxy).to be_a(Enumerable)
    end
  end

  describe '#loaded?' do
    it 'returns false when connection is not loaded' do
      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      expect(proxy.loaded?).to be false
    end

    it 'returns true after connection is loaded' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      proxy.to_a
      expect(proxy.loaded?).to be true
    end
  end

  describe '#to_a' do
    it 'loads and returns records as array' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      result = proxy.to_a

      expect(result).to eq(mock_orders)
      expect(result).to be_a(Array)
      expect(proxy.loaded?).to be true
    end

    it 'returns a duplicate array to prevent external modification' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      result1 = proxy.to_a
      result2 = proxy.to_a

      expect(result1).to eq(result2)
      expect(result1).not_to equal(result2)
    end

    it 'returns empty array when loader returns nil' do
      allow(mock_loader).to receive(:load_connection_records).and_return(nil)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      result = proxy.to_a

      expect(result).to eq([])
      expect(result).to be_a(Array)
    end

    it 'returns empty array when loader returns empty array' do
      allow(mock_loader).to receive(:load_connection_records).and_return([])

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      result = proxy.to_a

      expect(result).to eq([])
      expect(result).to be_a(Array)
    end

    it 'does not reload if already loaded' do
      allow(mock_loader).to receive(:load_connection_records).once.and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      proxy.to_a
      proxy.to_a
      proxy.to_a

      expect(mock_loader).to have_received(:load_connection_records).once
    end
  end

  describe '#each' do
    it 'iterates over connection records' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      result = []
      proxy.each { |order| result << order }

      expect(result).to eq(mock_orders)
    end

    it 'loads records before iterating' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      expect(proxy.loaded?).to be false
      proxy.each { |_order| }
      expect(proxy.loaded?).to be true
    end

    it 'returns an enumerator when no block is given' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      enumerator = proxy.each

      expect(enumerator).to be_a(Enumerator)
      expect(enumerator.to_a).to eq(mock_orders)
    end
  end

  describe '#size, #length, #count' do
    it 'returns the count of records' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      expect(proxy.size).to eq(3)
      expect(proxy.length).to eq(3)
      expect(proxy.count).to eq(3)
    end

    it 'returns 0 for empty connection' do
      allow(mock_loader).to receive(:load_connection_records).and_return([])

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      expect(proxy.size).to eq(0)
      expect(proxy.length).to eq(0)
      expect(proxy.count).to eq(0)
    end

    it 'loads records if not already loaded' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      expect(proxy.loaded?).to be false
      proxy.size
      expect(proxy.loaded?).to be true
    end
  end

  describe '#empty?' do
    it 'returns false when connection has records' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      expect(proxy.empty?).to be false
    end

    it 'returns true when connection is empty' do
      allow(mock_loader).to receive(:load_connection_records).and_return([])

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      expect(proxy.empty?).to be true
    end

    it 'loads records if not already loaded' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      expect(proxy.loaded?).to be false
      proxy.empty?
      expect(proxy.loaded?).to be true
    end
  end

  describe '#first' do
    it 'returns first record without argument' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      expect(proxy.first).to eq(mock_orders.first)
      expect(proxy.first.name).to eq('#1001')
    end

    it 'returns first n records when argument provided' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      result = proxy.first(2)

      expect(result).to eq(mock_orders.first(2))
      expect(result.size).to eq(2)
    end

    it 'returns nil when connection is empty' do
      allow(mock_loader).to receive(:load_connection_records).and_return([])

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      expect(proxy.first).to be_nil
    end

    it 'loads records if not already loaded' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      expect(proxy.loaded?).to be false
      proxy.first
      expect(proxy.loaded?).to be true
    end
  end

  describe '#last' do
    it 'returns last record without argument' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      expect(proxy.last).to eq(mock_orders.last)
      expect(proxy.last.name).to eq('#1003')
    end

    it 'returns last n records when argument provided' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      result = proxy.last(2)

      expect(result).to eq(mock_orders.last(2))
      expect(result.size).to eq(2)
    end

    it 'returns nil when connection is empty' do
      allow(mock_loader).to receive(:load_connection_records).and_return([])

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      expect(proxy.last).to be_nil
    end

    it 'loads records if not already loaded' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      expect(proxy.loaded?).to be false
      proxy.last
      expect(proxy.loaded?).to be true
    end
  end

  describe '#[]' do
    it 'returns record at given index' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      expect(proxy[0]).to eq(mock_orders[0])
      expect(proxy[1]).to eq(mock_orders[1])
      expect(proxy[2]).to eq(mock_orders[2])
    end

    it 'supports negative indices' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      expect(proxy[-1]).to eq(mock_orders[-1])
      expect(proxy[-2]).to eq(mock_orders[-2])
    end

    it 'supports range indices' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      expect(proxy[0..1]).to eq(mock_orders[0..1])
      expect(proxy[1..]).to eq(mock_orders[1..])
    end

    it 'returns nil for out of bounds index' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      expect(proxy[99]).to be_nil
    end

    it 'loads records if not already loaded' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      expect(proxy.loaded?).to be false
      proxy[0]
      expect(proxy.loaded?).to be true
    end
  end

  describe '#reload' do
    it 'marks connection as not loaded' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      proxy.to_a
      expect(proxy.loaded?).to be true

      proxy.reload
      expect(proxy.loaded?).to be false
    end

    it 'returns self for method chaining' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      result = proxy.reload

      expect(result).to equal(proxy)
    end

    it 'reloads records on next access' do
      call_count = 0
      allow(mock_loader).to receive(:load_connection_records) do
        call_count += 1
        mock_orders
      end

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      proxy.to_a
      expect(call_count).to eq(1)

      proxy.reload
      proxy.to_a
      expect(call_count).to eq(2)
    end
  end

  describe 'loading behavior' do
    it 'uses loader class from connection config if provided' do
      custom_loader_class = Class.new(ActiveShopifyGraphQL::AdminApiLoader)
      custom_loader_instance = instance_double(custom_loader_class)

      allow(custom_loader_class).to receive(:new).with(order_class).and_return(custom_loader_instance)
      allow(custom_loader_instance).to receive(:load_connection_records).and_return(mock_orders)

      config_with_custom_loader = connection_config.merge(loader_class: custom_loader_class)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: config_with_custom_loader,
        options: options
      )

      proxy.to_a

      expect(custom_loader_class).to have_received(:new).with(order_class)
      expect(custom_loader_instance).to have_received(:load_connection_records)
    end

    it 'uses parent class default loader when loader_class is nil' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      proxy.to_a

      expect(customer_class).to have_received(:default_loader)
      expect(mock_loader).to have_received(:load_connection_records)
    end

    it 'passes correct arguments to load_connection_records' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      proxy.to_a

      expect(mock_loader).to have_received(:load_connection_records).with(
        'orders',
        { first: 10 },
        parent,
        connection_config
      )
    end

    it 'merges default arguments with runtime options' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      runtime_options = { first: 20, sort_key: 'UPDATED_AT', reverse: true }

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: runtime_options
      )

      proxy.to_a

      expect(mock_loader).to have_received(:load_connection_records).with(
        'orders',
        { first: 20, sort_key: 'UPDATED_AT', reverse: true },
        parent,
        connection_config
      )
    end

    it 'runtime options override default arguments' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      runtime_options = { first: 5 }

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: runtime_options
      )

      proxy.to_a

      expect(mock_loader).to have_received(:load_connection_records).with(
        'orders',
        { first: 5 },
        parent,
        connection_config
      )
    end

    it 'skips nil values in variables' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      runtime_options = { first: 10, sort_key: nil }

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: runtime_options
      )

      proxy.to_a

      expect(mock_loader).to have_received(:load_connection_records).with(
        'orders',
        { first: 10 },
        parent,
        connection_config
      )
    end

    it 'passes through all argument types correctly' do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)

      runtime_options = {
        first: 10,
        sort_key: 'CREATED_AT',
        reverse: true,
        query: 'status:open'
      }

      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: runtime_options
      )

      proxy.to_a

      expect(mock_loader).to have_received(:load_connection_records).with(
        'orders',
        runtime_options,
        parent,
        connection_config
      )
    end
  end

  describe 'Enumerable methods' do
    before do
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)
    end

    it 'supports map' do
      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      result = proxy.map(&:name)

      expect(result).to eq(['#1001', '#1002', '#1003'])
    end

    it 'supports select' do
      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      result = proxy.select { |order| order.name == '#1002' }

      expect(result.size).to eq(1)
      expect(result.first.name).to eq('#1002')
    end

    it 'supports find' do
      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      result = proxy.find { |order| order.name == '#1002' }

      expect(result).to eq(mock_orders[1])
      expect(result.name).to eq('#1002')
    end

    it 'supports any?' do
      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      expect(proxy.any? { |order| order.name == '#1002' }).to be true
      expect(proxy.any? { |order| order.name == '#9999' }).to be false
    end

    it 'supports all?' do
      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      expect(proxy.all? { |order| order.name.start_with?('#') }).to be true
      expect(proxy.all? { |order| order.name == '#1001' }).to be false
    end

    it 'supports none?' do
      proxy = described_class.new(
        parent: parent,
        connection_name: connection_name,
        connection_config: connection_config,
        options: options
      )

      expect(proxy.none? { |order| order.name == '#9999' }).to be true
      expect(proxy.none? { |order| order.name == '#1001' }).to be false
    end
  end
end
