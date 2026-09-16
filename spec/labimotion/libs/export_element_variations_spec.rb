# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/labimotion/libs/export_element_variations'
require_relative '../../support/element_variation_doubles'

RSpec.describe Labimotion::ExportElementVariations do
  let(:element) { ElementVariationDoubles.element }
  let(:record) { ElementVariationDoubles.record }
  let(:segment_klasses) { [ElementVariationDoubles.segment_klass] }

  subject(:exporter) do
    described_class.new(element, variation: record, segment_klasses: segment_klasses)
  end

  # Reach into the built workbook rather than re-parsing the stream.
  def worksheet(name = 'Variations')
    exporter.read
    exporter.send(:exporter).workbook.worksheets.find { |sheet| sheet.name == name }
  end

  def row_values(sheet, index)
    sheet.rows[index].cells.map(&:value)
  end

  describe 'the Variations sheet' do
    let(:sheet) { worksheet }

    # Rows 0-2 are the banded header, 3 the machine keys, 4 the units, 5+ data.
    let(:keys) { row_values(sheet, 3) }
    let(:first_data_row) { 5 }

    it 'writes the group, sub-group and leaf header rows' do
      expect(row_values(sheet, 0)).to eq(
        ['Row ID', 'Variation', 'Properties', '', '', '', '', 'Metadata', '', '', 'Segments'],
      )
      expect(row_values(sheet, 1)).to eq(
        ['', '', 'Conditions', '', '', '', '', 'Notes', 'Analyses (IDs)', 'Group', 'My Segment'],
      )
      expect(row_values(sheet, 2)).to eq(
        ['', '', 'Temperature [C]', 'Solvent', 'Tags', 'Cycles', 'Link Analyses (IDs)', '', '', '', 'Mass [g]'],
      )
    end

    it 'merges each header across the columns it spans' do
      # Axlsx keeps the merge list private; there is no public reader for it.
      merged = sheet.send(:merged_cells).to_a
      # Properties spans its four fields plus the analyses link; Conditions, its
      # only layer, spans the same columns one row down.
      expect(merged).to include('C1:G1', 'C2:G2')
      expect(merged).to include('H1:J1')
      # Identity columns and metadata leaves have no level below them.
      expect(merged).to include('A1:A3', 'B1:B3')
      expect(merged).to include('H2:H3', 'I2:I3', 'J2:J3')
      # A single-column group needs no horizontal merge.
      expect(merged).not_to include('K1:K1', 'K2:K2')
    end

    it 'writes keys and units below the header' do
      expect(keys.first(3)).to eq(%w[__uuid __variation prop:layerconditionsfieldtemperature])
      expect(row_values(sheet, 4).first(3)).to eq(['', '', 'C'])
    end

    it 'hides the machine key and unit rows' do
      expect(sheet.rows[0..2].map(&:hidden)).to all(be_falsey)
      expect(sheet.rows[3].hidden).to be(true)
      expect(sheet.rows[4].hidden).to be(true)
      expect(sheet.rows[5].hidden).to be_falsey
    end

    it 'writes one data row per variation, in layout rowOrder' do
      expect(sheet.rows.length).to eq(7)
      expect(row_values(sheet, 5)[0]).to eq('uuid-a')
      expect(row_values(sheet, 6)[0]).to eq('uuid-b')
    end

    it 'writes numeric fields as numbers' do
      temperature = row_values(sheet, 5)[2]
      cycles = row_values(sheet, 5)[5]
      expect(temperature).to eq(20)
      expect(temperature).to be_a(Numeric)
      expect(cycles).to eq(1)
    end

    it 'joins select-multi values with a semicolon' do
      expect(row_values(sheet, 6)[4]).to eq('a; b')
    end

    it 'joins linked analysis ids and leaves an empty list blank' do
      analyses_index = keys.index('prop:layerconditionsfield__analyses__')
      expect(row_values(sheet, 6)[analyses_index]).to eq('101')
      expect(row_values(sheet, 5)[analyses_index]).to be_nil
    end

    it 'writes metadata and segment cells' do
      row = row_values(sheet, first_data_row)
      expect(row[keys.index('meta:notes')]).to eq('first')
      expect(row[keys.index('meta:group')]).to eq('1.1')
      expect(row[keys.index('seg:12:mass')]).to eq(1.5)
    end

    # Left to Axlsx's own type inference, "1.10" would be stored as the number
    # 1.1 and the group would come back truncated.
    it 'keeps numeric-looking text cells as text' do
      group_cell = sheet.rows[5].cells[keys.index('meta:group')]
      analyses_cell = sheet.rows[6].cells[keys.index('prop:layerconditionsfield__analyses__')]
      expect(group_cell.type).to eq(:string)
      expect(analyses_cell.type).to eq(:string)
    end

    it 'leaves genuinely numeric cells typed as numbers' do
      expect(sheet.rows[5].cells[keys.index('prop:layerconditionsfieldcycles')].type).to eq(:integer)
      expect(sheet.rows[5].cells[keys.index('seg:12:mass')].type).to eq(:float)
    end

    it 'freezes the header rows and the identity columns' do
      expect(sheet.sheet_view.pane.state.to_s).to eq('frozen')
      expect(sheet.sheet_view.pane.y_split).to eq(5)
      expect(sheet.sheet_view.pane.x_split).to eq(2)
    end
  end

  describe 'the Info sheet' do
    let(:sheet) { worksheet('Info') }

    it 'records the element and schema version' do
      values = sheet.rows.flat_map { |row| row.cells.map(&:value) }
      expect(values).to include('Element ID:', 42, 'Short label:', 'ME-1')
      expect(values).to include('Schema version:', described_class::SCHEMA_VERSION)
    end

    it 'lists the element analyses so the id column is readable' do
      values = sheet.rows.map { |row| row.cells.map(&:value) }
      expect(values).to include(['Analysis ID', 'Name', 'Kind'])
      expect(values).to include([101, 'IR spectrum', 'IR'])
      expect(values).to include([102, 'NMR', 'NMR'])
    end
  end

  describe '#filename' do
    it 'is derived from the element short label' do
      expect(exporter.filename).to match(/\AME-1_variations_\d{8}_\d{6}\.xlsx\z/)
    end
  end

  describe 'an element with no variations' do
    let(:record) { ElementVariationDoubles.record(variations: {}, layout: {}) }

    it 'still writes a usable header-only workbook' do
      sheet = worksheet
      expect(sheet.rows.length).to eq(5)
      expect(row_values(sheet, 3)).to include('__uuid', '__variation')
    end
  end

  describe '#read' do
    it 'produces a non-empty xlsx stream' do
      bytes = exporter.read
      expect(bytes).to be_a(String)
      expect(bytes[0, 2]).to eq('PK')
    end
  end
end
