# frozen_string_literal: true

require 'spec_helper'
require_relative '../../support/spec_entities'
require_relative '../../support/entity_mocks'

# Set up shared entity mocks
EntityMocks.setup!
EntityMocks.load_entities!

RSpec.describe Labimotion::VocabularyEntity do
  # Create mock classes for return values - defined at class level
  let(:mock_klass) { Struct.new(:label) }
  let(:basic_properties) do
    {
      id: 1,
      identifier: 'vocab_123',
      name: 'Test Vocabulary',
      label: 'Test Label',
      field_type: 'string',
      opid: 'op_123',
      term_id: 'term_456',
      field_id: 'field_789',
      source: 'test_source',
      source_id: 'source_123',
      layer_id: 'layer_456'
    }
  end

  before do
    stub_const('ElementKlass', Class.new do
      define_method(:initialize) { |mock_klass| @mock_klass = mock_klass }

      def self.find_by(identifier:)
        mock_struct = Struct.new(:label)
        return mock_struct.new('Element Label') if identifier == 'element_123'

        nil
      end
    end)

    stub_const('SegmentKlass', Class.new do
      def self.find_by(identifier:)
        mock_struct = Struct.new(:label)
        return mock_struct.new('Segment Label') if identifier == 'segment_456'

        nil
      end
    end)

    stub_const('DatasetKlass', Class.new do
      def self.find_by(identifier:)
        mock_struct = Struct.new(:label)
        return mock_struct.new('Dataset Label') if identifier == 'dataset_789'

        nil
      end
    end)
  end

  describe 'basic attribute exposure' do
    let(:entity_data) { SpecEntities::Vocabulary.new(basic_properties) }

    it 'exposes basic identity attributes' do
      entity = described_class.new(entity_data)

      expect(entity).to respond_to(:id)
      expect(entity).to respond_to(:identifier)
      expect(entity).to respond_to(:name)
    end

    it 'exposes label and type attributes' do
      entity = described_class.new(entity_data)

      expect(entity).to respond_to(:label)
      expect(entity).to respond_to(:field_type)
      expect(entity).to respond_to(:opid)
    end

    it 'exposes field and term attributes' do
      entity = described_class.new(entity_data)

      expect(entity).to respond_to(:term_id)
      expect(entity).to respond_to(:field_id)
      expect(entity).to respond_to(:properties)
    end

    it 'exposes source and layer attributes' do
      entity = described_class.new(entity_data)

      expect(entity).to respond_to(:source)
      expect(entity).to respond_to(:source_id)
      expect(entity).to respond_to(:layer_id)
    end

    it 'returns correct values for identity attributes' do
      entity = described_class.new(entity_data)

      expect(entity.id).to eq(1)
      expect(entity.identifier).to eq('vocab_123')
      expect(entity.name).to eq('Test Vocabulary')
    end

    it 'returns correct values for label and type attributes' do
      entity = described_class.new(entity_data)

      expect(entity.label).to eq('Test Label')
      expect(entity.field_type).to eq('string')
    end
  end

  describe '#voc' do
    context 'when properties contain voc with ELEMENT source' do
      let(:properties) do
        {
          'voc' => {
            'source' => Labimotion::Prop::ELEMENT,
            'source_id' => 'element_123'
          }
        }
      end
      let(:entity_data) { SpecEntities::Vocabulary.new(basic_properties.merge(properties: properties)) }

      it 'adds source_name from ElementKlass' do
        entity = described_class.new(entity_data)
        voc_result = entity.voc(entity_data)

        expect(voc_result['source_name']).to eq('Element Label')
        expect(voc_result['source']).to eq(Labimotion::Prop::ELEMENT)
      end
    end

    context 'when properties contain voc with SEGMENT source' do
      let(:properties) do
        {
          'voc' => {
            'source' => Labimotion::Prop::SEGMENT,
            'source_id' => 'segment_456'
          }
        }
      end
      let(:entity_data) { SpecEntities::Vocabulary.new(basic_properties.merge(properties: properties)) }

      it 'adds source_name from SegmentKlass' do
        entity = described_class.new(entity_data)
        voc_result = entity.voc(entity_data)

        expect(voc_result['source_name']).to eq('Segment Label')
        expect(voc_result['source']).to eq(Labimotion::Prop::SEGMENT)
      end
    end

    context 'when properties contain voc with DATASET source' do
      let(:properties) do
        {
          'voc' => {
            'source' => Labimotion::Prop::DATASET,
            'source_id' => 'dataset_789'
          }
        }
      end
      let(:entity_data) { SpecEntities::Vocabulary.new(basic_properties.merge(properties: properties)) }

      it 'adds source_name from DatasetKlass' do
        entity = described_class.new(entity_data)
        voc_result = entity.voc(entity_data)

        expect(voc_result['source_name']).to eq('Dataset Label')
        expect(voc_result['source']).to eq(Labimotion::Prop::DATASET)
      end
    end

    context 'when properties do not contain voc' do
      let(:entity_data) { SpecEntities::Vocabulary.new(basic_properties) }

      it 'returns empty hash when no voc in properties' do
        entity = described_class.new(entity_data)
        voc_result = entity.voc(entity_data)

        expect(voc_result).to eq({})
      end
    end
  end
end
