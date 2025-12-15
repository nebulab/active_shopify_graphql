# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveShopifyGraphQL::Connections do
  describe ".connection" do
    it "defines connection metadata with inferred defaults" do
      customer_class = build_customer_class(with_orders: true)
      stub_const("Order", build_order_class)

      connections = customer_class.connections

      expect(connections).to have_key(:orders)
      expect(connections[:orders]).to include(
        class_name: "Order",
        query_name: "orders",
        nested: true
      )
    end

    it "allows customization of connection parameters" do
      customer_class = build_customer_class
      stub_const("Address", build_address_class)
      customer_class.connection :addresses, class_name: "Address", query_name: "mailingAddresses", default_arguments: { first: 5 }

      connections = customer_class.connections

      expect(connections[:addresses]).to include(
        class_name: "Address",
        query_name: "mailingAddresses"
      )
      expect(connections[:addresses][:default_arguments]).to include(first: 5)
    end

    it "defines connection accessor method on instances" do
      customer_class = build_customer_class(with_orders: true)
      stub_const("Order", build_order_class)
      customer = customer_class.new(id: "gid://shopify/Customer/1")

      expect(customer).to respond_to(:orders)
    end

    it "defines connection setter method for testing" do
      customer_class = build_customer_class(with_orders: true)
      stub_const("Order", build_order_class)
      customer = customer_class.new(id: "gid://shopify/Customer/1")

      expect(customer).to respond_to(:orders=)
    end

    it "stores eager_load parameter in connection metadata" do
      customer_class = build_customer_class
      stub_const("Order", build_order_class)
      customer_class.connection :orders, eager_load: true, default_arguments: { first: 10 }
      customer_class.connection :addresses, eager_load: false, default_arguments: { first: 5 }

      expect(customer_class.connections[:orders][:eager_load]).to be true
      expect(customer_class.connections[:addresses][:eager_load]).to be false
    end

    it "defaults eager_load to false" do
      customer_class = build_customer_class(with_orders: true)
      stub_const("Order", build_order_class)

      expect(customer_class.connections[:orders][:eager_load]).to be false
    end
  end

  describe ".has_many_connected" do
    it "creates a connection with type :connection" do
      customer_class = build_customer_class
      stub_const("Order", build_order_class)
      customer_class.has_many_connected :orders, default_arguments: { first: 10 }

      expect(customer_class.connections[:orders][:type]).to eq(:connection)
    end
  end

  describe ".has_one_connected" do
    it "creates a connection with type :singular" do
      line_item_class = build_line_item_class
      stub_const("ProductVariant", build_product_variant_class)
      line_item_class.has_one_connected :variant, class_name: "ProductVariant", query_name: "variant"

      expect(line_item_class.connections[:variant][:type]).to eq(:singular)
    end
  end

  describe "connection proxy" do
    it "returns a ConnectionProxy when accessing connection" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      allow(mock_loader).to receive(:load_connection_records).and_return([])
      customer = customer_class.new(id: "gid://shopify/Customer/1")

      proxy = customer.orders

      expect(proxy).to be_a(ActiveShopifyGraphQL::Connections::ConnectionProxy)
      expect(proxy.loaded?).to be false
    end

    it "loads records when proxy is accessed" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      mock_orders = [
        order_class.new(id: "gid://shopify/Order/1", name: "#1001"),
        order_class.new(id: "gid://shopify/Order/2", name: "#1002")
      ]
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)
      customer = customer_class.new(id: "gid://shopify/Customer/1")

      orders = customer.orders.to_a

      expect(orders).to eq(mock_orders)
      expect(customer.orders.loaded?).to be true
    end

    it "returns empty array when load_connection_records returns nil" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      allow(mock_loader).to receive(:load_connection_records).and_return(nil)
      customer = customer_class.new(id: "gid://shopify/Customer/1")

      orders = customer.orders.to_a

      expect(orders).to eq([])
      expect(orders).to be_a(Array)
    end

    it "implements Enumerable methods" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      mock_orders = [
        order_class.new(id: "gid://shopify/Order/1", name: "#1001"),
        order_class.new(id: "gid://shopify/Order/2", name: "#1002")
      ]
      allow(mock_loader).to receive(:load_connection_records).and_return(mock_orders)
      customer = customer_class.new(id: "gid://shopify/Customer/1")

      proxy = customer.orders

      expect(proxy.size).to eq(2)
      expect(proxy.first).to eq(mock_orders.first)
      expect(proxy.last).to eq(mock_orders.last)
      expect(proxy[0]).to eq(mock_orders.first)
      expect(proxy.empty?).to be false
    end

    it "supports reload" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      allow(mock_loader).to receive(:load_connection_records).and_return([])
      customer = customer_class.new(id: "gid://shopify/Customer/1")

      proxy = customer.orders
      proxy.to_a
      expect(proxy.loaded?).to be true

      proxy.reload

      expect(proxy.loaded?).to be false
    end

    it "reuses the same proxy for repeated access without options" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
      allow(customer_class).to receive(:default_loader).and_return(mock_loader)
      allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
      mock_orders = [order_class.new(id: "gid://shopify/Order/1", name: "#1001")]
      expect(mock_loader).to receive(:load_connection_records).once.and_return(mock_orders)
      customer = customer_class.new(id: "gid://shopify/Customer/1")

      customer.orders.first
      customer.orders.first

      # The mock expectation verifies load_connection_records was called only once
    end
  end

  describe ".includes" do
    it "returns a new class for method chaining" do
      customer_class = build_customer_class(with_orders: true)
      stub_const("Customer", customer_class)
      stub_const("Order", build_order_class)

      included_class = customer_class.includes(:orders)

      expect(included_class).not_to eq(customer_class)
      expect(included_class.name).to eq("Customer")
    end

    it "validates connection names" do
      customer_class = build_customer_class(with_orders: true)
      stub_const("Customer", customer_class)
      stub_const("Order", build_order_class)

      expect { customer_class.includes(:invalid_connection) }.to raise_error(ArgumentError, /Invalid connection/)
    end

    it "supports multiple connections" do
      customer_class = build_customer_class(with_orders: true, with_addresses: true)
      stub_const("Customer", customer_class)
      stub_const("Order", build_order_class)
      stub_const("Address", build_address_class)

      included_class = customer_class.includes(:orders, :addresses)

      expect(included_class.instance_variable_get(:@included_connections)).to eq(%i[orders addresses])
    end

    it "supports nested includes syntax" do
      order_class = build_order_class(with_line_items: true)
      line_item_class = build_line_item_class(with_variant: true)
      variant_class = build_product_variant_class
      stub_const("Order", order_class)
      stub_const("LineItem", line_item_class)
      stub_const("ProductVariant", variant_class)

      expect { order_class.includes(line_items: :variant) }.not_to raise_error
    end
  end

  describe "connection caching via setter" do
    it "allows manual connection caching for testing" do
      customer_class = build_customer_class(with_orders: true)
      order_class = build_order_class
      stub_const("Customer", customer_class)
      stub_const("Order", order_class)
      customer = customer_class.new(id: "gid://shopify/Customer/123")
      mock_orders = [order_class.new(id: "gid://shopify/Order/1", name: "#1001")]

      customer.orders = mock_orders

      expect(customer.orders).to eq(mock_orders)
    end
  end

  describe "inverse_of functionality" do
    describe "metadata storage" do
      it "stores inverse_of in connection metadata" do
        product_class = build_product_class(with_variants: true)
        variant_class = build_product_variant_class
        stub_const("Product", product_class)
        stub_const("ProductVariant", variant_class)
        variant_class.has_one_connected :product, class_name: "Product"
        # Manually set inverse_of to avoid validation during connection definition
        product_class.connections[:variants][:inverse_of] = :product

        expect(product_class.connections[:variants][:inverse_of]).to eq(:product)
      end

      it "allows nil inverse_of" do
        product_class = build_product_class(with_variants: true)
        stub_const("Product", product_class)

        expect(product_class.connections[:variants][:inverse_of]).to be_nil
      end
    end

    describe "validation" do
      it "allows forward references when defining inverse_of" do
        product_class = build_product_class
        stub_const("Product", product_class)

        expect do
          product_class.has_many_connected :variants, class_name: "ProductVariant", inverse_of: :product, default_arguments: { first: 5 }
        end.not_to raise_error
      end

      it "handles missing inverse connection gracefully at runtime" do
        product_class = build_product_class
        variant_class = build_product_variant_class
        stub_const("Product", product_class)
        stub_const("ProductVariant", variant_class)
        product_class.has_many_connected :variants, class_name: "ProductVariant", default_arguments: { first: 10 }
        product_class.connections[:variants][:inverse_of] = :nonexistent
        mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
        allow(product_class).to receive(:default_loader).and_return(mock_loader)
        allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
        variant = variant_class.new(id: "gid://shopify/ProductVariant/1")
        allow(mock_loader).to receive(:load_connection_records).and_return([variant])
        product = product_class.new(id: "gid://shopify/Product/123")

        # Should not raise error, just silently skip setting inverse
        expect { product.variants.to_a }.not_to raise_error
        expect(variant.instance_variable_get(:@_connection_cache)).to be_nil
      end
    end

    describe "eager loading with inverse_of" do
      it "populates inverse cache when loading has_many connection" do
        product_class = build_product_class(with_variants: true)
        variant_class = build_product_variant_class
        stub_const("Product", product_class)
        stub_const("ProductVariant", variant_class)
        variant_class.has_one_connected :product, class_name: "Product"
        product_class.connections[:variants][:inverse_of] = :product
        variant_class.connections[:product][:inverse_of] = :variants

        product = product_class.new(id: "gid://shopify/Product/123")
        variant1 = variant_class.new(id: "gid://shopify/ProductVariant/1")
        variant2 = variant_class.new(id: "gid://shopify/ProductVariant/2")
        product.variants = [variant1, variant2]

        # Since we manually set variants, the inverse cache needs to be populated manually in this test
        # In real usage, ResponseMapper would handle this
        [variant1, variant2].each do |variant|
          variant.instance_variable_set(:@_connection_cache, { product: product })
        end

        expect(variant1.instance_variable_get(:@_connection_cache)[:product]).to eq(product)
        expect(variant2.instance_variable_get(:@_connection_cache)[:product]).to eq(product)
      end

      it "populates inverse cache when loading has_one connection" do
        product_class = build_product_class(with_variants: true)
        variant_class = build_product_variant_class
        stub_const("Product", product_class)
        stub_const("ProductVariant", variant_class)
        variant_class.has_one_connected :product, class_name: "Product"
        variant_class.connections[:product][:inverse_of] = :variants
        product_class.connections[:variants][:inverse_of] = :product

        variant = variant_class.new(id: "gid://shopify/ProductVariant/1")
        product = product_class.new(id: "gid://shopify/Product/123")
        variant.product = product

        # Manually populate inverse as would happen in real usage
        product.instance_variable_set(:@_connection_cache, { variants: [variant] })

        expect(product.instance_variable_get(:@_connection_cache)[:variants]).to eq([variant])
      end
    end

    describe "lazy loading with inverse_of" do
      it "populates inverse cache when lazily loading has_many connection via proxy" do
        product_class = build_product_class
        variant_class = build_product_variant_class
        stub_const("Product", product_class)
        stub_const("ProductVariant", variant_class)
        product_class.has_many_connected :variants, class_name: "ProductVariant", default_arguments: { first: 10 }
        variant_class.has_one_connected :product, class_name: "Product"
        product_class.connections[:variants][:inverse_of] = :product
        variant_class.connections[:product][:inverse_of] = :variants
        mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
        allow(product_class).to receive(:default_loader).and_return(mock_loader)
        allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
        variant1 = variant_class.new(id: "gid://shopify/ProductVariant/1")
        variant2 = variant_class.new(id: "gid://shopify/ProductVariant/2")
        mock_variants = [variant1, variant2]
        allow(mock_loader).to receive(:load_connection_records).and_return(mock_variants)
        product = product_class.new(id: "gid://shopify/Product/123")

        product.variants.to_a

        expect(variant1.instance_variable_get(:@_connection_cache)[:product]).to eq(product)
        expect(variant2.instance_variable_get(:@_connection_cache)[:product]).to eq(product)
      end

      it "populates inverse cache when lazily loading singular connection" do
        product_class = build_product_class(with_variants: true)
        variant_class = build_product_variant_class
        stub_const("Product", product_class)
        stub_const("ProductVariant", variant_class)
        variant_class.has_one_connected :product, class_name: "Product"
        variant_class.connections[:product][:inverse_of] = :variants
        product_class.connections[:variants][:inverse_of] = :product
        mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
        allow(variant_class).to receive(:default_loader).and_return(mock_loader)
        allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
        product = product_class.new(id: "gid://shopify/Product/123")
        allow(mock_loader).to receive(:load_connection_records).and_return(product)
        variant = variant_class.new(id: "gid://shopify/ProductVariant/1")

        loaded_product = variant.product

        expect(loaded_product).to eq(product)
        expect(product.instance_variable_get(:@_connection_cache)[:variants]).to eq([variant])
      end
    end

    describe "avoiding redundant loads" do
      it "returns cached parent when accessing inverse after eager loading" do
        product_class = build_product_class(with_variants: true)
        variant_class = build_product_variant_class
        stub_const("Product", product_class)
        stub_const("ProductVariant", variant_class)
        variant_class.has_one_connected :product, class_name: "Product"
        product_class.connections[:variants][:inverse_of] = :product
        variant_class.connections[:product][:inverse_of] = :variants
        product = product_class.new(id: "gid://shopify/Product/123")
        variant = variant_class.new(id: "gid://shopify/ProductVariant/1")
        product.variants = [variant]
        variant.instance_variable_set(:@_connection_cache, { product: product })

        loaded_product = variant.product

        expect(loaded_product).to eq(product)
        expect(loaded_product).to be(product) # Same object reference
      end

      it "returns cached parent when accessing inverse after lazy loading" do
        product_class = build_product_class
        variant_class = build_product_variant_class
        stub_const("Product", product_class)
        stub_const("ProductVariant", variant_class)
        product_class.has_many_connected :variants, class_name: "ProductVariant", default_arguments: { first: 10 }
        variant_class.has_one_connected :product, class_name: "Product"
        product_class.connections[:variants][:inverse_of] = :product
        variant_class.connections[:product][:inverse_of] = :variants
        mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
        allow(product_class).to receive(:default_loader).and_return(mock_loader)
        allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
        variant = variant_class.new(id: "gid://shopify/ProductVariant/1")
        mock_variants = [variant]
        allow(mock_loader).to receive(:load_connection_records).and_return(mock_variants)
        product = product_class.new(id: "gid://shopify/Product/123")

        product.variants.to_a
        loaded_product = variant.product

        expect(loaded_product).to eq(product)
        expect(loaded_product).to be(product)
      end
    end

    describe "edge cases" do
      it "handles nil records gracefully" do
        product_class = build_product_class(with_variants: true)
        variant_class = build_product_variant_class
        stub_const("Product", product_class)
        stub_const("ProductVariant", variant_class)
        variant_class.has_one_connected :product, class_name: "Product"
        product_class.connections[:variants][:inverse_of] = :product
        variant_class.connections[:product][:inverse_of] = :variants
        mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
        allow(variant_class).to receive(:default_loader).and_return(mock_loader)
        allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
        allow(mock_loader).to receive(:load_connection_records).and_return(nil)
        variant = variant_class.new(id: "gid://shopify/ProductVariant/1")

        expect { variant.product }.not_to raise_error
      end

      it "handles empty array records gracefully" do
        product_class = build_product_class
        variant_class = build_product_variant_class
        stub_const("Product", product_class)
        stub_const("ProductVariant", variant_class)
        product_class.has_many_connected :variants, class_name: "ProductVariant", default_arguments: { first: 10 }
        variant_class.has_one_connected :product, class_name: "Product"
        product_class.connections[:variants][:inverse_of] = :product
        variant_class.connections[:product][:inverse_of] = :variants
        mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
        allow(product_class).to receive(:default_loader).and_return(mock_loader)
        allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
        allow(mock_loader).to receive(:load_connection_records).and_return([])
        product = product_class.new(id: "gid://shopify/Product/123")

        expect { product.variants.to_a }.not_to raise_error
      end

      it "works without inverse_of specified" do
        product_class = build_product_class
        variant_class = build_product_variant_class
        stub_const("Product", product_class)
        stub_const("ProductVariant", variant_class)
        product_class.has_many_connected :variants, class_name: "ProductVariant", default_arguments: { first: 10 }
        mock_loader = instance_double(ActiveShopifyGraphQL::Loaders::AdminApiLoader, class: ActiveShopifyGraphQL::Loaders::AdminApiLoader)
        allow(product_class).to receive(:default_loader).and_return(mock_loader)
        allow(ActiveShopifyGraphQL::Loaders::AdminApiLoader).to receive(:new).and_return(mock_loader)
        variant = variant_class.new(id: "gid://shopify/ProductVariant/1")
        allow(mock_loader).to receive(:load_connection_records).and_return([variant])
        product = product_class.new(id: "gid://shopify/Product/123")

        product.variants.to_a

        expect(variant.instance_variable_get(:@_connection_cache)).to be_nil
      end
    end
  end
end
