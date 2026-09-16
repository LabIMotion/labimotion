# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/labimotion/libs/element_variation_column_set'
require_relative '../../support/element_variation_doubles'

RSpec.describe Labimotion::ElementVariationColumnSet do
  let(:element) { ElementVariationDoubles.element }
  let(:segment_klasses) { [ElementVariationDoubles.segment_klass] }
  let(:record) { ElementVariationDoubles.record }

  def build(rec = record)
    described_class.new(element, rec, segment_klasses: segment_klasses)
  end

  describe 'property key encoding' do
    it 'round-trips a layer/field pair' do
      key = described_class.encode_property_key('conditions', 'temperature')
      expect(key).to eq('layerconditionsfieldtemperature')
      expect(described_class.decode_property_key(key))
        .to eq(layer_key: 'conditions', field_key: 'temperature')
    end

    it 'recognises the analyses pseudo-field' do
      key = described_class.encode_property_key('conditions', described_class::ANALYSES_FIELD)
      expect(described_class.analyses_property_key?(key)).to be(true)
      expect(described_class.analyses_property_key?('layerconditionsfieldsolvent')).to be(false)
    end

    it 'returns nil for a key that is not a property key' do
      expect(described_class.decode_property_key('meta:notes')).to be_nil
    end
  end

  describe '#columns' do
    subject(:columns) { build.columns }

    it 'starts with the uuid and name columns' do
      expect(columns.first(2).map(&:key)).to eq(%w[__uuid __variation])
      expect(columns.first(2).map(&:kind)).to eq(%i[uuid name])
    end

    it 'orders columns as properties, analyses link, metadata, then segments' do
      expect(columns.map(&:key)).to eq(
        %w[
          __uuid
          __variation
          prop:layerconditionsfieldtemperature
          prop:layerconditionsfieldsolvent
          prop:layerconditionsfieldtags
          prop:layerconditionsfieldcycles
          prop:layerconditionsfield__analyses__
          meta:notes
          meta:analyses
          meta:group
          seg:12:mass
        ],
      )
    end

    it 'groups each column under its header path' do
      paths = columns.map { |col| [col.group, col.sub_group] }
      expect(paths.first(2)).to eq([[nil, nil], [nil, nil]])
      expect(paths[2]).to eq(['Properties', 'Conditions'])
      expect(paths[6]).to eq(['Properties', 'Conditions'])
      expect(paths[7]).to eq(['Metadata', nil])
      expect(paths[10]).to eq(['Segments', 'My Segment'])
    end

    # The exporter merges runs of adjacent columns that share a sub-group, so a
    # layer's columns have to stay together -- as they are in the grid, where the
    # analyses link is the last leaf of its layer group rather than a trailing
    # column of its own.
    it 'closes each layer with its analyses link column' do
      rec = ElementVariationDoubles.record(
        layout: ElementVariationDoubles.layout.merge(
          'selectedPropertyKeys' => %w[layerconditionsfieldsolvent layerworkupfieldyield],
          'selectedAnalysisLayers' => %w[conditions workup],
        ),
      )
      element = ElementVariationDoubles.element(element_klass: ElementVariationDoubles.two_layer_element_klass)
      columns = described_class.new(element, rec, segment_klasses: segment_klasses).columns

      expect(columns.map(&:key).first(6)).to eq(
        %w[
          __uuid
          __variation
          prop:layerconditionsfieldsolvent
          prop:layerconditionsfield__analyses__
          prop:layerworkupfieldyield
          prop:layerworkupfield__analyses__
        ],
      )
      expect(columns[2..5].map(&:sub_group)).to eq(['Conditions', 'Conditions', 'Workup', 'Workup'])
    end

    it 'places an analyses-only layer after the layers that have fields' do
      rec = ElementVariationDoubles.record(
        layout: ElementVariationDoubles.layout.merge(
          'selectedPropertyKeys' => %w[layerworkupfieldyield],
          'selectedAnalysisLayers' => %w[conditions workup],
        ),
      )
      element = ElementVariationDoubles.element(element_klass: ElementVariationDoubles.two_layer_element_klass)
      columns = described_class.new(element, rec, segment_klasses: segment_klasses).columns

      expect(columns.map(&:key).first(5)).to eq(
        %w[
          __uuid
          __variation
          prop:layerworkupfieldyield
          prop:layerworkupfield__analyses__
          prop:layerconditionsfield__analyses__
        ],
      )
    end

    it 'honours a custom groupOrder' do
      rec = ElementVariationDoubles.record(
        layout: ElementVariationDoubles.layout.merge('groupOrder' => %w[segments metadata properties]),
      )
      keys = build(rec).columns.map(&:key)
      expect(keys[2]).to eq('seg:12:mass')
      expect(keys[3]).to eq('meta:notes')
    end

    it 'labels a unit-bearing property with its unit token' do
      column = columns.find { |col| col.key == 'prop:layerconditionsfieldtemperature' }
      expect(column.label).to eq('Temperature [C]')
      expect(column.unit).to eq('C')
      expect(column.field_type).to eq('system-defined')
    end

    it 'omits the unit suffix for a unitless property' do
      column = columns.find { |col| col.key == 'prop:layerconditionsfieldsolvent' }
      expect(column.label).to eq('Solvent')
      expect(column.unit).to eq('')
    end

    it 'takes the segment unit from the field default when the layout has none' do
      column = columns.find { |col| col.key == 'seg:12:mass' }
      expect(column.label).to eq('Mass [g]')
      expect(column.unit).to eq('g')
    end

    it 'skips field types the grid does not offer as columns' do
      expect(columns.map(&:key)).not_to include('prop:layerconditionsfieldignored')
    end

    it 'exposes columns by key' do
      expect(build.lookup('meta:group').label).to eq('Group')
      expect(build.lookup('nope')).to be_nil
    end
  end

  describe 'unit resolution' do
    it 'prefers the layout columnUnits over the field default' do
      rec = ElementVariationDoubles.record(
        layout: ElementVariationDoubles.layout.merge(
          'columnUnits' => { 'prop:layerconditionsfieldtemperature' => 'K' },
        ),
      )
      column = build(rec).columns.find { |col| col.key == 'prop:layerconditionsfieldtemperature' }
      expect(column.unit).to eq('K')
    end

    it 'falls back to a unit inferred from the stored cells' do
      variations = ElementVariationDoubles.variations
      variations.each_value do |row|
        row['properties']['layerconditionsfieldtemperature']['unit'] = 'F'
      end
      layout = ElementVariationDoubles.layout.reject { |key, _| key == 'columnUnits' }
      rec = ElementVariationDoubles.record(variations: variations, layout: layout)

      column = build(rec).columns.find { |col| col.key == 'prop:layerconditionsfieldtemperature' }
      expect(column.unit).to eq('F')
    end
  end

  describe '#rows' do
    it 'follows the layout rowOrder' do
      expect(build.rows.map { |row| row['uuid'] }).to eq(%w[uuid-a uuid-b])
    end

    it 'appends rows missing from rowOrder, uuid-sorted' do
      rec = ElementVariationDoubles.record(
        layout: ElementVariationDoubles.layout.merge('rowOrder' => ['uuid-b']),
      )
      expect(build(rec).rows.map { |row| row['uuid'] }).to eq(%w[uuid-b uuid-a])
    end

    it 'sorts by uuid when there is no rowOrder' do
      rec = ElementVariationDoubles.record(layout: {})
      expect(build(rec).rows.map { |row| row['uuid'] }).to eq(%w[uuid-a uuid-b])
    end
  end

  describe 'layout-free inference' do
    subject(:columns) { build(ElementVariationDoubles.record(layout: {})).columns }

    it 'derives property columns from the stored data' do
      expect(columns.map(&:key)).to include(
        'prop:layerconditionsfieldtemperature',
        'prop:layerconditionsfieldsolvent',
      )
    end

    it 'derives the analyses link column from the stored data' do
      expect(columns.map(&:key)).to include('prop:layerconditionsfield__analyses__')
    end

    it 'derives segment columns from the stored data' do
      expect(columns.map(&:key)).to include('seg:12:mass')
    end

    it 'shows all metadata columns' do
      expect(columns.map(&:key)).to include('meta:notes', 'meta:analyses', 'meta:group')
    end
  end
end
