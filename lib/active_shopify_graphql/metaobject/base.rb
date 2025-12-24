# frozen_string_literal: true

module ActiveShopifyGraphQL
  module Metaobject
    # Base class for Metaobject-backed models.
    #
    # Metaobjects differ from regular GraphQL models in several ways:
    # - They use the metaobjects(type: "xxx") query instead of direct type queries
    # - Fields are accessed via a fields array with key/value pairs
    # - The metaobject "type" must be specified
    #
    # @example Defining a Metaobject model
    #   class Provider < ActiveShopifyGraphQL::Metaobject::Base
    #     metaobject_type "provider"
    #
    #     attribute :description
    #     attribute :name
    #   end
    #
    # @example Finding a metaobject
    #   Provider.find("gid://shopify/Metaobject/123")
    #   Provider.where(display_name: "Acme").first
    #
    class Base
      include ActiveModel::AttributeAssignment
      include ActiveModel::Validations
      extend ActiveModel::Naming

      class << self
        # Set or get the metaobject type (the "type" argument used in GraphQL queries)
        # If not explicitly set, infers from the class name (e.g., Provider -> "provider")
        # @param type [String, nil] The metaobject type to set
        # @return [String] The metaobject type
        def metaobject_type(type = nil)
          return @metaobject_type = type if type

          @metaobject_type ||= name.demodulize.underscore
        end

        # The GraphQL type is always "Metaobject" for metaobjects
        def graphql_type
          "Metaobject"
        end

        # Define an attribute on the metaobject.
        # This maps to a field in the metaobject's fields array.
        #
        # @param name [Symbol] The Ruby attribute name
        # @param key [String, nil] The metaobject field key (defaults to name)
        # @param type [Symbol] The type for coercion (:string, :integer, :float, :boolean, :datetime, :json)
        # @param default [Object] Default value when field is nil
        # @param transform [Proc] Custom transform block for the value
        def attribute(name, key: nil, type: :string, default: nil, transform: nil)
          key ||= name.to_s
          config = { key: key, type: type, default: default, transform: transform }

          @metaobject_attributes ||= {}
          @metaobject_attributes[name] = config

          attr_accessor name unless method_defined?(name) || method_defined?("#{name}=")
        end

        # Get all defined metaobject attributes
        def metaobject_attributes
          @metaobject_attributes ||= {}
        end

        # Inherit metaobject attributes from parent class
        def inherited(subclass)
          super
          subclass.instance_variable_set(:@metaobject_attributes, metaobject_attributes.dup)
        end

        # Returns a Relation for querying metaobjects
        # @return [MetaobjectRelation] A new relation for this model
        def all
          MetaobjectRelation.new(self)
        end

        # Find a single metaobject by ID
        # @param id [String] The metaobject GID
        # @return [Object] The metaobject instance
        # @raise [ActiveShopifyGraphQL::ObjectNotFoundError] If not found
        def find(id)
          all.find(id)
        end

        # Find a single metaobject by conditions
        # @param conditions [Hash] The conditions to query
        # @return [Object, nil] The first matching instance or nil
        def find_by(conditions = {}, **options)
          all.find_by(conditions.empty? ? options : conditions)
        end

        # Query for multiple metaobjects
        # @param conditions [Hash, String] The conditions to query
        # @return [MetaobjectRelation] A chainable relation
        def where(conditions = {}, *args, **options)
          all.where(conditions, *args, **options)
        end

        # Returns the default loader class for metaobjects
        def default_loader_class
          Loaders::AdminApiLoader
        end
      end

      # Instance methods

      def initialize(attributes = {})
        assign_attributes(attributes)
      end

      # Convenience accessor for the model's ID
      attr_accessor :id

      # Convenience accessor for the handle
      attr_accessor :handle

      # Convenience accessor for displayName
      attr_accessor :display_name

      # Convenience accessor for type
      attr_accessor :type
    end
  end
end
