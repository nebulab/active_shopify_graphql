# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Automatic array support' do
  let(:loader_class) do
    Class.new(ActiveShopifyGraphQL::Loader) do
      graphql_type 'TestType'

      attribute :tags                                  # No type specified - arrays preserved automatically
      attribute :single_tag, type: :string             # String type, but arrays still preserved
      attribute :nullable_tags, null: true             # No type specified
      attribute :non_nullable_tags, null: false        # No type specified
      attribute :numeric_values, type: :integer        # Integer type, but arrays still preserved
    end
  end

  let(:loader) { loader_class.new }

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
      loader_class.class_eval do
        attribute :transformed_tags, type: :array, transform: ->(value) { value.map(&:upcase) }
      end

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

      attributes = loader.map_response_to_attributes(response_data)

      expect(attributes[:transformed_tags]).to eq(%w[LOWER CASE])
    end
  end

  describe 'type coercion with arrays' do
    it 'preserves arrays even when type coercion is specified' do
      mapper = ActiveShopifyGraphQL::ResponseMapper.new(loader)

      # Test string type coercer with array input
      expect(mapper.coerce_value(%w[a b c], :string, :test, 'test')).to eq(%w[a b c])

      # Test integer type coercer with array input
      expect(mapper.coerce_value([1, 2, 3], :integer, :test, 'test')).to eq([1, 2, 3])

      # Test boolean type coercer with array input
      expect(mapper.coerce_value([true, false], :boolean, :test, 'test')).to eq([true, false])
    end

    it 'still performs type coercion for non-array values' do
      mapper = ActiveShopifyGraphQL::ResponseMapper.new(loader)

      expect(mapper.coerce_value('42', :integer, :test, 'test')).to eq(42)
      expect(mapper.coerce_value('true', :boolean, :test, 'test')).to eq(true)
      expect(mapper.coerce_value(42, :string, :test, 'test')).to eq('42')
    end

    it 'handles nil values correctly' do
      mapper = ActiveShopifyGraphQL::ResponseMapper.new(loader)

      expect(mapper.coerce_value(nil, :string, :test, 'test')).to be_nil
      expect(mapper.coerce_value(nil, :integer, :test, 'test')).to be_nil
    end

    it 'handles empty arrays' do
      mapper = ActiveShopifyGraphQL::ResponseMapper.new(loader)

      expect(mapper.coerce_value([], :string, :test, 'test')).to eq([])
      expect(mapper.coerce_value([], :integer, :test, 'test')).to eq([])
    end
  end
end
