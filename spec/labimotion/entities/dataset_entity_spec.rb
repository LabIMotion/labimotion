# frozen_string_literal: true

require 'spec_helper'
require_relative '../../support/spec_entities'
require_relative '../../support/entity_mocks'

# Set up shared entity mocks
EntityMocks.setup!
EntityMocks.load_entities!

RSpec.describe Labimotion::DatasetEntity do
  # Helper method to format timestamps consistently with the actual eln_timestamp formatter
  def format_timestamp(datetime_string)
    datetime = DateTime.parse(datetime_string)
    datetime.present? ? datetime.strftime('%Y-%m-%d %H:%M:%S %Z') : nil
  end

  let(:dataset_klass) do
    SpecEntities::DatasetKlass.new(
      id: 1,
      ols_term_id: 'OLS:12345',
      label: 'Test Dataset Klass',
      uuid: 'dataset-klass-uuid-123'
    )
  end

  let(:basic_properties) do
    {
      id: 1,
      dataset_klass_id: 1,
      properties: { 'test_prop' => 'test_value' },
      properties_release: { 'release_prop' => 'release_value' },
      element_id: 100,
      element_type: 'Sample',
      klass_uuid: 'dataset-uuid-456',
      dataset_klass: dataset_klass
    }
  end

  describe 'basic attribute exposure' do
    let(:entity_data) { SpecEntities::Dataset.new(basic_properties) }

    it 'exposes all basic attributes' do
      entity = described_class.new(entity_data)

      expect(entity).to respond_to(:id)
      expect(entity).to respond_to(:dataset_klass_id)
      expect(entity).to respond_to(:properties)
    end

    it 'exposes additional basic attributes' do
      entity = described_class.new(entity_data)

      expect(entity).to respond_to(:properties_release)
      expect(entity).to respond_to(:element_id)
      expect(entity).to respond_to(:element_type)
    end

    it 'exposes klass-related attributes' do
      entity = described_class.new(entity_data)

      expect(entity).to respond_to(:klass_ols)
      expect(entity).to respond_to(:klass_label)
      expect(entity).to respond_to(:klass_uuid)
    end

    it 'returns correct values for id and dataset_klass_id' do
      entity = described_class.new(entity_data)

      expect(entity.id).to eq(1)
      expect(entity.dataset_klass_id).to eq(1)
    end

    it 'returns correct values for properties' do
      entity = described_class.new(entity_data)

      expect(entity.properties).to be_nil
      expect(entity.properties_release).to be_nil
    end

    it 'returns correct values for element attributes' do
      entity = described_class.new(entity_data)

      expect(entity.element_id).to eq(100)
      expect(entity.element_type).to eq('Sample')
      expect(entity.klass_uuid).to eq('dataset-uuid-456')
    end
  end

  describe 'association-based methods' do
    context 'when dataset_klass is present' do
      let(:entity_data) { SpecEntities::Dataset.new(basic_properties) }

      it 'returns klass_ols from associated dataset_klass' do
        entity = described_class.new(entity_data)
        expect(entity.klass_ols).to eq('OLS:12345')
      end

      it 'returns klass_label from associated dataset_klass' do
        entity = described_class.new(entity_data)
        expect(entity.klass_label).to eq('Test Dataset Klass')
      end
    end

    context 'when dataset_klass is nil' do
      let(:entity_data) { SpecEntities::Dataset.new(basic_properties.merge(dataset_klass: nil)) }

      it 'safely handles nil dataset_klass for klass_ols' do
        entity = described_class.new(entity_data)
        expect(entity.klass_ols).to be_nil
      end

      it 'safely handles nil dataset_klass for klass_label' do
        entity = described_class.new(entity_data)
        expect(entity.klass_label).to be_nil
      end
    end

    context 'when dataset_klass has nil attributes' do
      let(:nil_attribute_klass) do
        SpecEntities::DatasetKlass.new(
          id: 2,
          ols_term_id: nil,
          label: nil,
          uuid: 'dataset-klass-uuid-456'
        )
      end
      let(:entity_data) { SpecEntities::Dataset.new(basic_properties.merge(dataset_klass: nil_attribute_klass)) }

      it 'returns nil for klass_ols when ols_term_id is nil' do
        entity = described_class.new(entity_data)
        expect(entity.klass_ols).to be_nil
      end

      it 'returns nil for klass_label when label is nil' do
        entity = described_class.new(entity_data)
        expect(entity.klass_label).to be_nil
      end
    end
  end

  describe 'edge cases' do
    context 'when entity has missing attributes' do
      let(:minimal_data) { SpecEntities::Dataset.new(id: 1) }

      it 'handles missing basic attributes gracefully' do
        entity = described_class.new(minimal_data)

        expect(entity.id).to eq(1)
        expect(entity.dataset_klass_id).to be_nil
        expect(entity.properties).to be_nil
      end

      it 'handles missing properties gracefully' do
        entity = described_class.new(minimal_data)

        expect(entity.properties_release).to be_nil
        expect(entity.element_id).to be_nil
        expect(entity.element_type).to be_nil
      end

      it 'handles missing klass attributes gracefully' do
        entity = described_class.new(minimal_data)

        expect(entity.klass_uuid).to be_nil
        expect(entity.klass_ols).to be_nil
        expect(entity.klass_label).to be_nil
      end
    end

    context 'when properties are complex objects' do
      let(:complex_properties) do
        {
          properties: {
            'fields' => [
              { 'name' => 'temperature', 'value' => '25.5', 'unit' => 'C' },
              { 'name' => 'pressure', 'value' => '1.0', 'unit' => 'atm' }
            ],
            'metadata' => {
              'instrument' => 'HPLC-MS',
              'operator' => 'lab_user'
            }
          },
          properties_release: {
            'status' => 'published',
            'version' => '1.2',
            'checksums' => {
              'md5' => 'abc123',
              'sha256' => 'def456'
            }
          },
          displayed_in_list: false
        }
      end
      let(:entity_data) { SpecEntities::Dataset.new(basic_properties.merge(complex_properties)) }

      it 'handles complex properties structure' do
        entity = described_class.new(entity_data)

        properties = entity.properties
        expect(properties['fields']).to be_an(Array)
        expect(properties['fields'].length).to eq(2)
      end

      it 'handles complex metadata structure' do
        entity = described_class.new(entity_data)

        properties = entity.properties
        expect(properties['metadata']['instrument']).to eq('HPLC-MS')
      end

      it 'handles complex release properties' do
        entity = described_class.new(entity_data)

        release = entity.properties_release
        expect(release['status']).to eq('published')
        expect(release['checksums']['md5']).to eq('abc123')
      end
    end
  end

  describe 'inheritance from PropertiesEntity' do
    let(:entity_data) { SpecEntities::Dataset.new(basic_properties) }

    it 'inherits from PropertiesEntity (which inherits from ApplicationEntity)' do
      entity = described_class.new(entity_data)

      # Verify inheritance chain
      expect(described_class.superclass.name).to include('PropertiesEntity')

      # Should respond to methods from parent classes
      expect(entity).to respond_to(:properties)
      expect(entity).to respond_to(:properties_release)
    end
  end

  describe 'safe navigation patterns' do
    let(:entity_data) { SpecEntities::Dataset.new(basic_properties) }

    it 'uses safe navigation (&.) in custom methods' do
      entity = described_class.new(entity_data)

      # These methods should not raise errors even if object is nil
      # The implementation uses object&.dataset_klass&.ols_term_id pattern
      expect { entity.klass_ols }.not_to raise_error
      expect { entity.klass_label }.not_to raise_error
    end

    it 'demonstrates safe navigation with different data states' do
      # Test with various states to ensure safe navigation works
      test_cases = [
        { dataset_klass: nil },
        { dataset_klass: SpecEntities::DatasetKlass.new(id: 1, ols_term_id: nil, label: nil) },
        { dataset_klass: dataset_klass }
      ]

      test_cases.each do |test_data|
        entity_data = SpecEntities::Dataset.new(basic_properties.merge(test_data))
        entity = described_class.new(entity_data)

        expect { entity.klass_ols }.not_to raise_error
        expect { entity.klass_label }.not_to raise_error
      end
    end
  end
end
