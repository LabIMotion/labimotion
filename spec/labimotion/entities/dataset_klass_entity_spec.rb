# frozen_string_literal: true

require 'spec_helper'
require_relative '../../support/spec_entities'
require_relative '../../support/entity_mocks'

# Set up shared entity mocks
EntityMocks.setup!
EntityMocks.load_entities!

RSpec.describe Labimotion::DatasetKlassEntity do
  # Helper method to format timestamps consistently
  def format_timestamp(datetime_string)
    DateTime.parse(datetime_string).strftime('%Y-%m-%d %H:%M:%S %Z')
  end

  # Create a DatasetKlass test entity that extends GenericKlass with ols_term_id
  let(:dataset_klass_struct) do
    Struct.new(:id, :uuid, :label, :desc, :is_active, :version, :place,
               :released_at, :identifier, :sync_time, :properties_template,
               :properties_release, :created_at, :updated_at, :displayed_in_list,
               :ols_term_id, keyword_init: true)
  end

  let(:basic_properties) do
    {
      id: 1,
      uuid: 'test-dataset-klass-uuid-123',
      label: 'Test Dataset Klass',
      desc: 'Test dataset klass description',
      is_active: true,
      version: '1.0.0',
      place: 'dataset_place',
      released_at: DateTime.parse('2023-09-07 11:36:08.831'),
      identifier: 'dataset_klass_123',
      sync_time: DateTime.parse('2023-09-07 12:45:15.642'),
      properties_template: { 'dataset_template' => 'data' },
      properties_release: { 'dataset_release' => 'data' },
      created_at: DateTime.parse('2023-09-07 10:20:33.123'),
      updated_at: DateTime.parse('2023-09-07 13:15:42.987'),
      displayed_in_list: false,
      ols_term_id: 'OLS:123456'
    }
  end

  describe 'inheritance from GenericKlassEntity' do
    let(:entity_data) { dataset_klass_struct.new(basic_properties) }

    it 'inherits from GenericKlassEntity' do
      expect(described_class.superclass).to eq(Labimotion::GenericKlassEntity)
    end

    it 'exposes basic inherited attributes from GenericKlassEntity' do
      entity = described_class.new(entity_data)

      expect(entity).to respond_to(:id)
      expect(entity).to respond_to(:uuid)
      expect(entity).to respond_to(:label)
    end

    it 'exposes additional inherited attributes from GenericKlassEntity' do
      entity = described_class.new(entity_data)

      expect(entity).to respond_to(:desc)
      expect(entity).to respond_to(:is_active)
      expect(entity).to respond_to(:version)
    end

    it 'exposes location inherited attributes from GenericKlassEntity' do
      entity = described_class.new(entity_data)

      expect(entity).to respond_to(:place)
      expect(entity).to respond_to(:released_at)
    end

    it 'exposes sync inherited attributes from GenericKlassEntity' do
      entity = described_class.new(entity_data)

      expect(entity).to respond_to(:identifier)
      expect(entity).to respond_to(:sync_time)
    end

    it 'returns correct values for basic inherited attributes' do
      entity = described_class.new(entity_data)

      expect(entity.id).to eq(1)
      expect(entity.uuid).to eq('test-dataset-klass-uuid-123')
      expect(entity.label).to eq('Test Dataset Klass')
    end

    it 'returns correct values for additional inherited attributes' do
      entity = described_class.new(entity_data)

      expect(entity.desc).to eq('Test dataset klass description')
      expect(entity.is_active).to be true
      expect(entity.version).to eq('1.0.0')
    end

    it 'returns correct values for location inherited attributes' do
      entity = described_class.new(entity_data)

      expect(entity.place).to eq('dataset_place')
      expect(entity.identifier).to eq('dataset_klass_123')
    end

    it 'inherits timestamp formatting functionality for released_at and sync_time' do
      entity = described_class.new(entity_data)

      expect(entity.released_at).to eq(format_timestamp('2023-09-07 11:36:08.831'))
      expect(entity.sync_time).to eq(format_timestamp('2023-09-07 12:45:15.642'))
    end

    it 'inherits timestamp formatting functionality for created_at and updated_at' do
      entity = described_class.new(entity_data)

      expect(entity.created_at).to eq(format_timestamp('2023-09-07 10:20:33.123'))
      expect(entity.updated_at).to eq(format_timestamp('2023-09-07 13:15:42.987'))
    end
  end

  describe 'DatasetKlassEntity specific attributes' do
    let(:entity_data) { dataset_klass_struct.new(basic_properties) }

    it 'exposes ols_term_id attribute' do
      entity = described_class.new(entity_data)

      expect(entity).to respond_to(:ols_term_id)
      expect(entity.ols_term_id).to eq('OLS:123456')
    end

    it 'handles nil ols_term_id value' do
      entity_data_with_nil = dataset_klass_struct.new(basic_properties.merge(ols_term_id: nil))
      entity = described_class.new(entity_data_with_nil)

      expect(entity.ols_term_id).to be_nil
    end

    it 'handles missing ols_term_id attribute' do
      minimal_data = dataset_klass_struct.new(id: 1, label: 'Minimal Dataset Klass')
      entity = described_class.new(minimal_data)

      expect(entity.ols_term_id).to be_nil
    end
  end

  describe 'inherited conditional attribute exposure' do
    context 'when displayed_in_list is false' do
      let(:entity_data) { dataset_klass_struct.new(basic_properties.merge(displayed_in_list: false)) }

      it 'exposes properties_template and properties_release methods (inherited behavior)' do
        entity = described_class.new(entity_data)

        expect(entity).to respond_to(:properties_template)
        expect(entity).to respond_to(:properties_release)
      end

      it 'returns correct values for properties_template and properties_release (inherited behavior)' do
        entity = described_class.new(entity_data)

        expect(entity.properties_template).to eq({ 'dataset_template' => 'data' })
        expect(entity.properties_release).to eq({ 'dataset_release' => 'data' })
      end
    end

    context 'when displayed_in_list is not provided (testing default)' do
      let(:minimal_data) do
        dataset_klass_struct.new(
          id: 1,
          label: 'Minimal Dataset Klass',
          ols_term_id: 'OLS:999',
          # displayed_in_list not provided - should inherit default behavior
          properties_template: { 'minimal_dataset_template' => 'data' },
          properties_release: { 'minimal_dataset_release' => 'data' }
        )
      end

      it 'exposes properties methods for default displayed_in_list behavior' do
        entity = described_class.new(minimal_data)

        expect(entity).to respond_to(:properties_template)
        expect(entity).to respond_to(:properties_release)
      end

      it 'returns nil for properties when displayed_in_list is default (inherited behavior)' do
        entity = described_class.new(minimal_data)

        expect(entity.properties_template).to be_nil
        expect(entity.properties_release).to be_nil
      end

      it 'returns correct ols_term_id for default displayed_in_list behavior' do
        entity = described_class.new(minimal_data)

        expect(entity.ols_term_id).to eq('OLS:999')
        # Verify the underlying object has nil/missing displayed_in_list
        expect(entity.instance_variable_get(:@object).displayed_in_list).to be_nil
      end
    end
  end

  describe 'inherited constant' do
    it 'inherits DISPLAYED_IN_LIST_CONDITION constant' do
      expect(described_class::DISPLAYED_IN_LIST_CONDITION).to eq({ unless: :displayed_in_list })
    end
  end
end
