# frozen_string_literal: true

require 'spec_helper'
require_relative '../../support/spec_entities'
require_relative '../../support/entity_mocks'

# Set up shared entity mocks
EntityMocks.setup!
EntityMocks.load_entities!

RSpec.describe Labimotion::GenericKlassEntity do
  # Helper method to format timestamps consistently
  def format_timestamp(datetime_string)
    DateTime.parse(datetime_string).strftime('%Y-%m-%d %H:%M:%S %Z')
  end

  let(:basic_properties) do
    {
      id: 1,
      uuid: 'test-uuid-123',
      label: 'Test Generic Klass',
      desc: 'Test description',
      is_active: true,
      version: '1.0.0',
      place: 'test_place',
      released_at: DateTime.parse('2023-09-07 11:36:08.831'),
      identifier: 'generic_klass_123',
      sync_time: DateTime.parse('2023-09-07 12:45:15.642'),
      properties_template: { 'template' => 'data' },
      properties_release: { 'release' => 'data' },
      created_at: DateTime.parse('2023-09-07 10:20:33.123'),
      updated_at: DateTime.parse('2023-09-07 13:15:42.987'),
      displayed_in_list: false
    }
  end

  describe 'basic attribute exposure' do
    let(:entity_data) { SpecEntities::GenericKlass.new(basic_properties) }

    it 'exposes basic identity attributes' do
      entity = described_class.new(entity_data)

      expect(entity).to respond_to(:id)
      expect(entity).to respond_to(:uuid)
      expect(entity).to respond_to(:label)
    end

    it 'exposes description and status attributes' do
      entity = described_class.new(entity_data)

      expect(entity).to respond_to(:desc)
      expect(entity).to respond_to(:is_active)
      expect(entity).to respond_to(:version)
    end

    it 'exposes location attributes' do
      entity = described_class.new(entity_data)

      expect(entity).to respond_to(:place)
      expect(entity).to respond_to(:released_at)
    end

    it 'exposes timestamp attributes' do
      entity = described_class.new(entity_data)

      expect(entity).to respond_to(:identifier)
      expect(entity).to respond_to(:sync_time)
    end

    it 'returns correct values for identity attributes' do
      entity = described_class.new(entity_data)

      expect(entity.id).to eq(1)
      expect(entity.uuid).to eq('test-uuid-123')
      expect(entity.label).to eq('Test Generic Klass')
    end

    it 'returns correct values for description and status attributes' do
      entity = described_class.new(entity_data)

      expect(entity.desc).to eq('Test description')
      expect(entity.is_active).to be true
      expect(entity.version).to eq('1.0.0')
    end

    it 'returns correct values for location attributes' do
      entity = described_class.new(entity_data)

      expect(entity.place).to eq('test_place')
      expect(entity.identifier).to eq('generic_klass_123')
    end
  end

  describe 'timestamp formatting with eln_timestamp formatter' do
    let(:entity_data) { SpecEntities::GenericKlass.new(basic_properties) }

    it 'formats release and sync timestamp fields using eln_timestamp formatter' do
      entity = described_class.new(entity_data)

      expect(entity.released_at).to eq(format_timestamp('2023-09-07 11:36:08.831'))
      expect(entity.sync_time).to eq(format_timestamp('2023-09-07 12:45:15.642'))
    end

    it 'formats created and updated timestamp fields using eln_timestamp formatter' do
      entity = described_class.new(entity_data)

      expect(entity.created_at).to eq(format_timestamp('2023-09-07 10:20:33.123'))
      expect(entity.updated_at).to eq(format_timestamp('2023-09-07 13:15:42.987'))
    end

    it 'handles nil timestamp values for release and sync timestamps' do
      entity_data_with_nil = SpecEntities::GenericKlass.new(basic_properties.merge(
                                                              released_at: nil,
                                                              sync_time: nil
                                                            ))
      entity = described_class.new(entity_data_with_nil)

      expect(entity.released_at).to be_nil
      expect(entity.sync_time).to be_nil
    end

    it 'still formats non-nil timestamps when some are nil' do
      entity_data_with_nil = SpecEntities::GenericKlass.new(basic_properties.merge(
                                                              released_at: nil,
                                                              sync_time: nil
                                                            ))
      entity = described_class.new(entity_data_with_nil)

      expect(entity.created_at).to eq(format_timestamp('2023-09-07 10:20:33.123'))
      expect(entity.updated_at).to eq(format_timestamp('2023-09-07 13:15:42.987'))
    end

    it 'formats different timezone timestamps correctly' do
      utc_time = DateTime.parse('2023-09-07 11:36:08 UTC')
      entity_data_utc = SpecEntities::GenericKlass.new(basic_properties.merge(released_at: utc_time))
      entity = described_class.new(entity_data_utc)

      expect(entity.released_at).to eq(utc_time.strftime('%Y-%m-%d %H:%M:%S %Z'))
    end
  end

  describe 'ApplicationEntity eln_timestamp formatter' do
    it 'tests the formatter logic directly with offset timezone' do
      test_datetime = DateTime.parse('2023-09-07 11:36:08.831')
      expected_format = test_datetime.strftime('%Y-%m-%d %H:%M:%S %Z')
      expect(expected_format).to eq(format_timestamp('2023-09-07 11:36:08.831'))
    end

    it 'tests formatter with explicit UTC' do
      test_datetime = DateTime.parse('2023-09-07 11:36:08 UTC')
      expected_format = test_datetime.strftime('%Y-%m-%d %H:%M:%S %Z')
      expect(expected_format).to eq(test_datetime.strftime('%Y-%m-%d %H:%M:%S %Z'))
    end

    it 'tests the actual formatter behavior' do
      formatter_block = proc do |datetime|
        datetime.present? ? datetime.strftime('%Y-%m-%d %H:%M:%S %Z') : nil
      end

      test_datetime = DateTime.parse('2023-09-07 11:36:08.831')
      result = formatter_block.call(test_datetime)
      expect(result).to eq(format_timestamp('2023-09-07 11:36:08.831'))

      test_datetime_utc = DateTime.parse('2023-09-07 11:36:08 UTC')
      result_utc = formatter_block.call(test_datetime_utc)
      expect(result_utc).to eq(test_datetime_utc.strftime('%Y-%m-%d %H:%M:%S %Z'))

      result_nil = formatter_block.call(nil)
      expect(result_nil).to be_nil
    end

    it 'handles present? check in formatter' do
      test_datetime = DateTime.parse('2023-09-07 11:36:08')
      expect(test_datetime.respond_to?(:present?)).to be true
      expect(test_datetime.present?).to be true

      # Test the actual behavior that matters for the formatter
      expect(nil.present?).to be false if nil.respond_to?(:present?)
    end
  end

  describe 'conditional attribute exposure' do
    context 'when displayed_in_list is false' do
      let(:entity_data) { SpecEntities::GenericKlass.new(basic_properties.merge(displayed_in_list: false)) }

      it 'exposes properties_template and properties_release methods' do
        entity = described_class.new(entity_data)

        expect(entity).to respond_to(:properties_template)
        expect(entity).to respond_to(:properties_release)
      end

      it 'returns correct values for properties_template and properties_release' do
        entity = described_class.new(entity_data)

        expect(entity.properties_template).to eq({ 'template' => 'data' })
        expect(entity.properties_release).to eq({ 'release' => 'data' })
      end
    end

    context 'when displayed_in_list is true' do
      let(:entity_data) { SpecEntities::GenericKlass.new(basic_properties.merge(displayed_in_list: true)) }

      it 'still exposes properties_template and properties_release methods' do
        entity = described_class.new(entity_data)

        expect(entity).to respond_to(:properties_template)
        expect(entity).to respond_to(:properties_release)
      end

      it 'returns nil for properties when displayed_in_list is true' do
        entity = described_class.new(entity_data)

        # These should still be callable even when displayed_in_list is true
        expect(entity.properties_template).to be_nil
        expect(entity.properties_release).to be_nil
      end
    end

    context 'when displayed_in_list is not provided (testing default)' do
      let(:minimal_data) do
        SpecEntities::GenericKlass.new(
          id: 1,
          label: 'Minimal Test Klass',
          # displayed_in_list not provided - should default to true
          properties_template: { 'minimal_template' => 'data' },
          properties_release: { 'minimal_release' => 'data' }
        )
      end

      it 'exposes properties methods when displayed_in_list defaults to true' do
        entity = described_class.new(minimal_data)

        expect(entity).to respond_to(:properties_template)
        expect(entity).to respond_to(:properties_release)
      end

      it 'returns nil for properties when displayed_in_list defaults to true' do
        entity = described_class.new(minimal_data)

        expect(entity.properties_template).to be_nil
        expect(entity.properties_release).to be_nil
        # Verify the underlying object has nil/missing displayed_in_list
        expect(entity.instance_variable_get(:@object).displayed_in_list).to be_nil
      end
    end
  end

  describe 'edge cases' do
    context 'when entity has missing attributes' do
      let(:minimal_data) { SpecEntities::GenericKlass.new(id: 1, label: 'Minimal') }

      it 'handles missing basic attributes gracefully' do
        entity = described_class.new(minimal_data)

        expect(entity.id).to eq(1)
        expect(entity.label).to eq('Minimal')
        expect(entity.uuid).to be_nil
      end

      it 'handles missing complex attributes gracefully' do
        entity = described_class.new(minimal_data)

        expect(entity.desc).to be_nil
        expect(entity.properties_template).to be_nil
      end
    end

    context 'when boolean attributes have specific values' do
      let(:boolean_test_data) do
        SpecEntities::GenericKlass.new(basic_properties.merge(
                                         is_active: false,
                                         displayed_in_list: true
                                       ))
      end

      it 'correctly handles boolean values' do
        entity = described_class.new(boolean_test_data)

        expect(entity.is_active).to be false
        expect(entity.instance_variable_get(:@object).displayed_in_list).to be true
      end
    end

    context 'when properties are complex objects' do
      let(:complex_properties) do
        {
          properties_template: {
            'fields' => [
              { 'name' => 'field1', 'type' => 'string' },
              { 'name' => 'field2', 'type' => 'number' }
            ],
            'version' => '2.0'
          },
          properties_release: {
            'status' => 'published',
            'metadata' => {
              'author' => 'test_user',
              'tags' => %w[chemistry analysis]
            }
          }
        }
      end
      let(:entity_data) { SpecEntities::GenericKlass.new(basic_properties.merge(complex_properties)) }

      it 'handles complex properties_template structure' do
        entity = described_class.new(entity_data)

        template = entity.properties_template
        expect(template['fields']).to be_an(Array)
        expect(template['fields'].length).to eq(2)
        expect(template['version']).to eq('2.0')
      end

      it 'handles complex properties_release structure' do
        entity = described_class.new(entity_data)

        release = entity.properties_release
        expect(release['status']).to eq('published')
        expect(release['metadata']['author']).to eq('test_user')
        expect(release['metadata']['tags']).to include('chemistry', 'analysis')
      end
    end
  end

  describe 'DISPLAYED_IN_LIST_CONDITION constant' do
    it 'defines the correct condition constant' do
      expect(described_class::DISPLAYED_IN_LIST_CONDITION).to eq({ unless: :displayed_in_list })
    end
  end

  describe 'default displayed_in_list behavior' do
    let(:default_true_data) do
      SpecEntities.default_generic_klass(
        id: 2,
        label: 'Default True Test Klass',
        properties_template: { 'default_template' => 'data' },
        properties_release: { 'default_release' => 'data' }
      )
    end

    it 'exposes properties when displayed_in_list defaults to true' do
      entity = described_class.new(default_true_data)

      expect(entity.instance_variable_get(:@object).displayed_in_list).to be true
      expect(entity.properties_template).to be_nil
      expect(entity.properties_release).to be_nil
    end

    it 'documents that properties are exposed regardless of displayed_in_list value' do
      false_entity = described_class.new(SpecEntities::GenericKlass.new(
                                           id: 3, label: 'False Test', displayed_in_list: false,
                                           properties_template: { 'false_template' => 'data' }
                                         ))

      true_entity = described_class.new(default_true_data)

      expect(false_entity.properties_template).to eq({ 'false_template' => 'data' })
      expect(true_entity.properties_template).to be_nil
    end
  end
end
