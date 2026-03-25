# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Testing
    # Prepended onto LoaderSwitchable::ClassMethods to redirect
    # default_loader_class to TestLoader when testing is enabled.
    module LoaderSwitchableHook
      private

      def default_loader_class
        return super unless ActiveShopifyGraphQL::Testing.enabled?

        ActiveShopifyGraphQL::Testing::TestLoader
      end
    end

    # Prepended onto FinderMethods::ClassMethods to return fresh
    # TestLoader instances (preventing memoization leaks between tests).
    module FinderMethodsHook
      def default_loader
        return super unless ActiveShopifyGraphQL::Testing.enabled?

        # Return a fresh instance each time to prevent state leakage between tests.
        eagerly_loaded_connections = connections.select { |_name, config| config[:eager_load] }.keys
        ActiveShopifyGraphQL::Testing::TestLoader.new(
          self,
          included_connections: eagerly_loaded_connections
        )
      end
    end

    # Prepended onto Attributes::ClassMethods so that attributes_for_loader
    # returns attributes from ALL loader contexts when TestLoader is the
    # requested loader. Without this, attributes defined only inside
    # for_loader blocks (e.g. email on AdminApiLoader) would be invisible
    # to the testing harness.
    module AttributesHook
      def attributes_for_loader(loader_class)
        if ActiveShopifyGraphQL::Testing.enabled? && loader_class == ActiveShopifyGraphQL::Testing::TestLoader
          base = instance_variable_get(:@base_attributes) || {}
          loader_contexts = instance_variable_get(:@loader_contexts) || {}

          merged = base.dup
          loader_contexts.each_value { |ctx_attrs| merged.merge!(ctx_attrs) { |_key, base_val, _override_val| base_val } }
          return merged
        end

        super
      end
    end

    # Prepended onto GraphqlTypeResolver::ClassMethods so that graphql_type
    # (with no argument) falls back to graphql_type_for_loader(TestLoader)
    # when testing is enabled. Models that only define graphql_type inside
    # for_loader blocks have no @base_graphql_type and would otherwise raise.
    module GraphqlTypeResolverHook
      def graphql_type(type = nil)
        super
      rescue NotImplementedError
        raise unless ActiveShopifyGraphQL::Testing.enabled?

        graphql_type_for_loader(ActiveShopifyGraphQL::Testing::TestLoader)
      end
    end
  end
end
