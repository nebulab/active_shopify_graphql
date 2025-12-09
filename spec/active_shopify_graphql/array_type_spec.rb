# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Automatic array support' do
  model_class = Class.new do
    include ActiveShopifyGraphQL::Attributes

    attribute :tags                                  # No type specified - arrays preserved automatically
    attribute :single_tag, type: :string             # String type, but arrays still preserved
    attribute :nullable_tags, null: true             # No type specified
    attribute :non_nullable_tags, null: false        # No type specified
    attribute :numeric_values, type: :integer        # Integer type, but arrays still preserved

    def self.name
      'TestType'
    end
  end

  loader_class = Class.new(ActiveShopifyGraphQL::Loader) do
    graphql_type 'TestType'
    self.model_class = model_class
  end

  loader = loader_class.new

  describe 'automatic array preservation' do
    it 'preserves arrays regardless of specified type' do
      response_data = {
        'data' => {
          'testtype' => { # NOTE: query_name returns lowercase
            'tags' => %w[tag1 tag2 tag3],
            'singleTag' => %w[single],
            'nullableTags' => nil,
            'nonNullableTags' => %w[required tag],
            'numericValues' => [1, 2, 3]
          }
        }
      }

      attributes = loader.map_response_to_attributes(response_data)

      expect(attributes[:tags]).to eq(%w[tag1 tag2 tag3])
      expect(attributes[:single_tag]).to eq(%w[single]) # Array preserved even with type: :string
      expect(attributes[:nullable_tags]).to be_nil
      expect(attributes[:non_nullable_tags]).to eq(%w[required tag])
      expect(attributes[:numeric_values]).to eq([1, 2, 3]) # Array preserved even with type: :integer
    end

    it 'raises error for null values when null is not allowed' do
      response_data = {
        'data' => {
          'testtype' => { # NOTE: query_name returns lowercase
            'tags' => ['tag1'],
            'singleTag' => %w[single],
            'nullableTags' => nil,
            'nonNullableTags' => nil, # This should cause an error
            'numericValues' => [1]
          }
        }
      }

      expect do
        loader.map_response_to_attributes(response_data)
      end.to raise_error(ArgumentError, /cannot be null/)
    end

    it 'handles empty arrays correctly' do
      response_data = {
        'data' => {
          'testtype' => {  # NOTE: query_name returns lowercase
            'tags' => [],
            'singleTag' => [],
            'nullableTags' => [],
            'nonNullableTags' => [],
            'numericValues' => []
          }
        }
      }

      attributes = loader.map_response_to_attributes(response_data)

      expect(attributes[:tags]).to eq([])
      expect(attributes[:single_tag]).to eq([])
      expect(attributes[:nullable_tags]).to eq([])
      expect(attributes[:non_nullable_tags]).to eq([])
      expect(attributes[:numeric_values]).to eq([])
    end

    it 'works with transform blocks' do
      transform_model_class = Class.new do
        include ActiveShopifyGraphQL::Attributes

        attribute :tags
        attribute :single_tag, type: :string
        attribute :nullable_tags, null: true
        attribute :non_nullable_tags, null: false
        attribute :numeric_values, type: :integer
        attribute :transformed_tags, type: :array, transform: ->(value) { value.map(&:upcase) }

        def self.name
          'TestType'
        end
      end

      transform_loader_class = Class.new(ActiveShopifyGraphQL::Loader) do
        graphql_type 'TestType'
        self.model_class = transform_model_class
      end

      transform_loader = transform_loader_class.new

      response_data = {
        'data' => {
          'testtype' => {  # NOTE: query_name returns lowercase
            'tags' => %w[tag1 tag2],
            'singleTag' => %w[single],
            'nullableTags' => nil,
            'nonNullableTags' => ['required'],
            'transformedTags' => %w[lower case],
            'numericValues' => [1, 2]
          }
        }
      }

      attributes = transform_loader.map_response_to_attributes(response_data)

      expect(attributes[:transformed_tags]).to eq(%w[LOWER CASE])
    end
  end

  describe 'type coercion with arrays' do
    # NOTE: coerce_value is now a private method in ResponseMapper.
    # These behaviors are tested through the public map_response method above.
    # The following tests verify array preservation through the full mapping flow.

    it 'preserves arrays through full response mapping' do
      response_data = {
        'data' => {
          'testtype' => {
            'tags' => %w[a b c],
            'singleTag' => %w[single],
            'nullableTags' => nil,
            'nonNullableTags' => %w[required],
            'numericValues' => [1, 2, 3]
          }
        }
      }

      attributes = loader.map_response_to_attributes(response_data)

      expect(attributes[:tags]).to eq(%w[a b c])
      expect(attributes[:numeric_values]).to eq([1, 2, 3])
    end

    it 'handles empty arrays' do
      response_data = {
        'data' => {
          'testtype' => {
            'tags' => [],
            'singleTag' => [],
            'nullableTags' => [],
            'nonNullableTags' => [],
            'numericValues' => []
          }
        }
      }

      attributes = loader.map_response_to_attributes(response_data)

      expect(attributes[:tags]).to eq([])
      expect(attributes[:numeric_values]).to eq([])
    end
  end
end
