# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require_relative '../../../lib/labimotion/libs/export_element_variations'
require_relative '../../../lib/labimotion/libs/import_element_variations'
require_relative '../../support/element_variation_doubles'

RSpec.describe Labimotion::ImportElementVariations do
  let(:element) { ElementVariationDoubles.element }
  let(:segment_klasses) { [ElementVariationDoubles.segment_klass] }

  # Write the workbook the exporter produces to disk, then read it back.
  def export_to_file(record)
    exporter = Labimotion::ExportElementVariations.new(
      element, variation: record, segment_klasses: segment_klasses
    )
    file = Tempfile.new(['variations', '.xlsx'])
    file.binmode
    file.write(exporter.read)
    file.flush
    file
  end

  def import(file, record)
    importer = described_class.new(element, file.path, segment_klasses: segment_klasses, record: record)
    [importer.execute!, importer]
  end

  describe 'round-trip' do
    it 'leaves the variations untouched when the exported file is imported back' do
      exported = export_to_file(ElementVariationDoubles.record)
      target = ElementVariationDoubles.record

      result, importer = import(exported, target)

      expect(importer.warnings).to be_empty
      expect(result.variations).to eq(ElementVariationDoubles.variations)
    ensure
      exported&.close!
    end

    it 'preserves the row order from the sheet' do
      exported = export_to_file(ElementVariationDoubles.record)
      target = ElementVariationDoubles.record

      result, = import(exported, target)

      expect(result.layout['rowOrder']).to eq(%w[uuid-a uuid-b])
    ensure
      exported&.close!
    end

    it 'saves the record once' do
      exported = export_to_file(ElementVariationDoubles.record)
      target = ElementVariationDoubles.record

      result, = import(exported, target)

      expect(result.save_count).to eq(1)
    ensure
      exported&.close!
    end
  end

  describe 'edits made in the spreadsheet' do
    let(:exported) { export_to_file(ElementVariationDoubles.record) }

    after { exported&.close! }

    # Edits one cell of the nth data row, the way a user editing the sheet would.
    # Locates the key row rather than assuming it, so this survives changes to
    # the header; merges are dropped on the way out, which the importer ignores.
    def rewrite(file, data_row, column_key, value)
      workbook = Roo::Spreadsheet.open(file.path, extension: :xlsx)
      sheet = workbook.sheet('Variations')
      key_row = (1..sheet.last_row).find { |number| Array(sheet.row(number)).include?('__uuid') }
      column = Array(sheet.row(key_row)).index(column_key)
      target_row = key_row + 1 + data_row

      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: 'Variations') do |out|
        (1..sheet.last_row).each do |number|
          cells = Array(sheet.row(number))
          cells[column] = value if number == target_row
          cells = cells.map { |cell| cell.nil? ? '' : cell }
          out.add_row(cells, types: cells.map { :string })
        end
      end
      updated = Tempfile.new(['edited', '.xlsx'])
      updated.binmode
      updated.write(package.to_stream.read)
      updated.flush
      updated
    end

    it 'applies a changed property value' do
      edited = rewrite(exported, 1, 'prop:layerconditionsfieldsolvent', 'acetone')
      result, = import(edited, ElementVariationDoubles.record)

      cell = result.variations['uuid-a']['properties']['layerconditionsfieldsolvent']
      expect(cell['value']).to eq('acetone')
      expect(cell['unit']).to eq('')
    ensure
      edited&.close!
    end

    it 'applies a changed variation name' do
      edited = rewrite(exported, 1, '__variation', 'renamed')
      result, = import(edited, ElementVariationDoubles.record)

      expect(result.variations['uuid-a']['name']).to eq('renamed')
    ensure
      edited&.close!
    end

    it 'keeps a numeric-looking group as text' do
      edited = rewrite(exported, 1, 'meta:group', '1.10')
      result, = import(edited, ElementVariationDoubles.record)

      expect(result.variations['uuid-a']['metadata']['group']).to eq('1.10')
    ensure
      edited&.close!
    end

    it 'strips characters the grid would not allow in a group' do
      edited = rewrite(exported, 1, 'meta:group', '1.1<script>')
      result, = import(edited, ElementVariationDoubles.record)

      expect(result.variations['uuid-a']['metadata']['group']).to eq('1.1script')
    ensure
      edited&.close!
    end

    it 'clears a property the user emptied' do
      edited = rewrite(exported, 1, 'prop:layerconditionsfieldsolvent', nil)
      result, = import(edited, ElementVariationDoubles.record)

      expect(result.variations['uuid-a']['properties']['layerconditionsfieldsolvent']['value']).to be_nil
    ensure
      edited&.close!
    end

    it 'names the cell that held a non-numeric analysis reference' do
      edited = rewrite(exported, 1, 'meta:analyses', 'aaaa')
      _, importer = import(edited, ElementVariationDoubles.record)

      expect(importer.warnings)
        .to eq(["Cell I6: ignored non-numeric analysis reference 'aaaa'."])
    ensure
      edited&.close!
    end

    it 'names the cell of a bad analysis reference on the second data row' do
      edited = rewrite(exported, 2, 'prop:layerconditionsfield__analyses__', 'nope')
      _, importer = import(edited, ElementVariationDoubles.record)

      expect(importer.warnings)
        .to eq(["Cell G7: ignored non-numeric analysis reference 'nope'."])
    ensure
      edited&.close!
    end

    it 'adds a new variation for a row with a blank Row ID' do
      edited = rewrite(exported, 1, '__uuid', nil)
      result, = import(edited, ElementVariationDoubles.record)

      # uuid-a is untouched (it was not in the sheet); the blank row is new.
      expect(result.variations.keys).to include('uuid-a', 'uuid-b')
      expect(result.variations.size).to eq(3)
      added = result.variations.keys - %w[uuid-a uuid-b]
      expect(result.variations[added.first]['name']).to eq('ME-1-v1')
    ensure
      edited&.close!
    end
  end

  # `number`, `integer` and `system-defined` columns hold a number or nothing;
  # the old fallback stored the raw text instead.
  describe 'numeric columns' do
    let(:exported) { export_to_file(ElementVariationDoubles.record) }

    after { exported&.close! }

    def rewrite(file, data_row, column_key, value)
      workbook = Roo::Spreadsheet.open(file.path, extension: :xlsx)
      sheet = workbook.sheet('Variations')
      key_row = (1..sheet.last_row).find { |number| Array(sheet.row(number)).include?('__uuid') }
      column = Array(sheet.row(key_row)).index(column_key)
      target_row = key_row + 1 + data_row

      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: 'Variations') do |out|
        (1..sheet.last_row).each do |number|
          cells = Array(sheet.row(number))
          cells[column] = value if number == target_row
          cells = cells.map { |cell| cell.nil? ? '' : cell }
          out.add_row(cells, types: cells.map { :string })
        end
      end
      updated = Tempfile.new(['numeric', '.xlsx'])
      updated.binmode
      updated.write(package.to_stream.read)
      updated.flush
      updated
    end

    # `prop:layerconditionsfieldtemperature` (system-defined) is column C.
    it 'clears a system-defined cell holding text and names it' do
      edited = rewrite(exported, 1, 'prop:layerconditionsfieldtemperature', 'aaa')
      result, importer = import(edited, ElementVariationDoubles.record)

      expect(importer.warnings)
        .to eq(["Cell C6: cleared 'aaa' - Temperature [C] takes numbers only."])
      expect(result.variations['uuid-a']['properties']['layerconditionsfieldtemperature'])
        .to eq('value' => nil, 'unit' => 'C')
    ensure
      edited&.close!
    end

    it 'clears a number with trailing text' do
      edited = rewrite(exported, 1, 'prop:layerconditionsfieldtemperature', '12abc')
      result, importer = import(edited, ElementVariationDoubles.record)

      expect(importer.warnings)
        .to eq(["Cell C6: cleared '12abc' - Temperature [C] takes numbers only."])
      expect(result.variations['uuid-a']['properties']['layerconditionsfieldtemperature']['value'])
        .to be_nil
    ensure
      edited&.close!
    end

    it 'clears a decimal in an integer column' do
      edited = rewrite(exported, 1, 'prop:layerconditionsfieldcycles', '1.5')
      result, importer = import(edited, ElementVariationDoubles.record)

      expect(importer.warnings)
        .to eq(["Cell F6: cleared '1.5' - Cycles takes whole numbers only."])
      expect(result.variations['uuid-a']['properties']['layerconditionsfieldcycles']['value']).to be_nil
    ensure
      edited&.close!
    end

    it 'clears text in a segment number column' do
      edited = rewrite(exported, 1, 'seg:12:mass', 'heavy')
      result, importer = import(edited, ElementVariationDoubles.record)

      expect(importer.warnings)
        .to eq(["Cell K6: cleared 'heavy' - Mass [g] takes numbers only."])
      expect(result.variations['uuid-a']['segments']['12']['mass']).to be_nil
    ensure
      edited&.close!
    end

    # The reported bug: text typed into the grid before these columns were
    # checked survived a round trip, because the import warned and then kept the
    # value already on record -- which was the same text.
    it 'clears text that was already on record, not just text from the sheet' do
      dirty = ElementVariationDoubles.variations
      dirty['uuid-a']['properties']['layerconditionsfieldtemperature']['value'] = 'aaaa'
      exported_dirty = export_to_file(ElementVariationDoubles.record(variations: dirty))

      result, importer = import(exported_dirty, ElementVariationDoubles.record(variations: dirty))

      expect(importer.warnings)
        .to eq(["Cell C6: cleared 'aaaa' - Temperature [C] takes numbers only."])
      expect(result.variations['uuid-a']['properties']['layerconditionsfieldtemperature']['value'])
        .to be_nil
    ensure
      exported_dirty&.close!
    end

    # Clearing is not the same as inventing: a column the row never carried
    # stays absent rather than gaining an empty cell.
    it 'does not add a property the row never had from a cell it cannot store' do
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: 'Variations') do |sheet|
        sheet.add_row(['Row ID', 'Variation', 'Temperature'])
        sheet.add_row(%w[__uuid __variation prop:layerconditionsfieldtemperature],
                      types: %i[string string string])
        sheet.add_row(['', '', 'C'], types: %i[string string string])
        sheet.add_row(['', 'fresh', 'aaa'], types: %i[string string string])
      end
      file = Tempfile.new(['fresh', '.xlsx'])
      file.binmode
      file.write(package.to_stream.read)
      file.flush

      result, importer = import(file, ElementVariationDoubles.record(variations: {}))

      expect(importer.warnings)
        .to eq(["Cell C4: cleared 'aaa' - Temperature [C] takes numbers only."])
      expect(result.variations.values.first['properties']).to eq({})
    ensure
      file&.close!
    end

    it 'reads a comma as the decimal separator' do
      edited = rewrite(exported, 1, 'seg:12:mass', '2,5')
      result, importer = import(edited, ElementVariationDoubles.record)

      expect(importer.warnings).to be_empty
      expect(result.variations['uuid-a']['segments']['12']['mass']).to eq(2.5)
    ensure
      edited&.close!
    end

    it 'still clears a numeric cell the user emptied' do
      edited = rewrite(exported, 1, 'prop:layerconditionsfieldtemperature', nil)
      result, importer = import(edited, ElementVariationDoubles.record)

      expect(importer.warnings).to be_empty
      expect(result.variations['uuid-a']['properties']['layerconditionsfieldtemperature']['value'])
        .to be_nil
    ensure
      edited&.close!
    end
  end

  describe 'merge semantics' do
    it 'leaves variations that the sheet does not mention untouched' do
      only_a = ElementVariationDoubles.variations.slice('uuid-a')
      layout = ElementVariationDoubles.layout.merge('rowOrder' => ['uuid-a'])
      exported = export_to_file(ElementVariationDoubles.record(variations: only_a, layout: layout))

      target = ElementVariationDoubles.record
      result, = import(exported, target)

      expect(result.variations['uuid-b']).to eq(ElementVariationDoubles.variations['uuid-b'])
    ensure
      exported&.close!
    end

    it 'does not invent property keys the row never had' do
      stripped = ElementVariationDoubles.variations
      stripped['uuid-a']['properties'].delete('layerconditionsfieldsolvent')
      exported = export_to_file(ElementVariationDoubles.record(variations: stripped))

      result, = import(exported, ElementVariationDoubles.record(variations: stripped))

      expect(result.variations['uuid-a']['properties']).not_to have_key('layerconditionsfieldsolvent')
    ensure
      exported&.close!
    end

    it 'appends untouched variations after the sheet rows in rowOrder' do
      only_b = ElementVariationDoubles.variations.slice('uuid-b')
      layout = ElementVariationDoubles.layout.merge('rowOrder' => ['uuid-b'])
      exported = export_to_file(ElementVariationDoubles.record(variations: only_b, layout: layout))

      result, = import(exported, ElementVariationDoubles.record)

      expect(result.layout['rowOrder']).to eq(%w[uuid-b uuid-a])
    ensure
      exported&.close!
    end
  end

  describe 'analysis links' do
    # `meta:analyses` is column I; uuid-a is the first data row, row 6.
    it 'drops analysis ids that do not belong to the element, naming the cell' do
      variations = ElementVariationDoubles.variations
      variations['uuid-a']['metadata']['analyses'] = [101, 999]
      exported = export_to_file(ElementVariationDoubles.record(variations: variations))

      result, importer = import(exported, ElementVariationDoubles.record(variations: variations))

      expect(result.variations['uuid-a']['metadata']['analyses']).to eq([101])
      expect(importer.warnings)
        .to eq(['Cell I6: ignored analysis id(s) 999 - they do not belong to this element.'])
    ensure
      exported&.close!
    end
  end

  describe 'invalid input' do
    it 'rejects a workbook without a Variations sheet' do
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: 'Other') { |sheet| sheet.add_row(%w[a b]) }
      file = Tempfile.new(['wrong', '.xlsx'])
      file.binmode
      file.write(package.to_stream.read)
      file.flush

      expect { import(file, ElementVariationDoubles.record) }
        .to raise_error(described_class::InvalidWorkbook, /Sheet 'Variations' not found/)
    ensure
      file&.close!
    end

    it 'rejects a Variations sheet without the machine key row' do
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: 'Variations') do |sheet|
        sheet.add_row(['Row ID', 'Variation'])
        sheet.add_row(['not', 'keys'])
        sheet.add_row(['', ''])
        sheet.add_row(%w[uuid-a name])
      end
      file = Tempfile.new(['nokeys', '.xlsx'])
      file.binmode
      file.write(package.to_stream.read)
      file.flush

      expect { import(file, ElementVariationDoubles.record) }
        .to raise_error(described_class::InvalidWorkbook, /No column key row found/)
    ensure
      file&.close!
    end

    it 'rejects a key row that is missing the variation name column' do
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: 'Variations') do |sheet|
        sheet.add_row(['Row ID'])
        sheet.add_row(['__uuid'], types: [:string])
        sheet.add_row([''], types: [:string])
        sheet.add_row(['uuid-a'], types: [:string])
      end
      file = Tempfile.new(['noname', '.xlsx'])
      file.binmode
      file.write(package.to_stream.read)
      file.flush

      expect { import(file, ElementVariationDoubles.record) }
        .to raise_error(described_class::InvalidWorkbook, /Row 2 is missing the column keys __variation/)
    ensure
      file&.close!
    end

    it 'rejects a file that is not an xlsx archive' do
      file = Tempfile.new(['garbage', '.xlsx'])
      file.write('definitely not a spreadsheet')
      file.flush

      expect { import(file, ElementVariationDoubles.record) }
        .to raise_error(described_class::InvalidWorkbook)
    ensure
      file&.close!
    end
  end

  # Before the banded header, the exporter wrote a single label row, putting the
  # keys on row 2 rather than row 4. Those files must still import.
  describe 'a workbook from the single-row-header export' do
    it 'finds the key row wherever it sits' do
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: 'Variations') do |sheet|
        sheet.add_row(['Row ID', 'Variation', 'Conditions · Solvent'])
        sheet.add_row(%w[__uuid __variation prop:layerconditionsfieldsolvent], types: %i[string string string])
        sheet.add_row(['', '', ''], types: %i[string string string])
        sheet.add_row(%w[uuid-a renamed acetone], types: %i[string string string])
      end
      file = Tempfile.new(['legacy', '.xlsx'])
      file.binmode
      file.write(package.to_stream.read)
      file.flush

      result, importer = import(file, ElementVariationDoubles.record)

      expect(importer.warnings).to be_empty
      expect(result.variations['uuid-a']['name']).to eq('renamed')
      expect(result.variations['uuid-a']['properties']['layerconditionsfieldsolvent']['value']).to eq('acetone')
    ensure
      file&.close!
    end
  end

  describe 'unknown columns' do
    it 'warns but still imports the columns it understands' do
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: 'Variations') do |sheet|
        sheet.add_row(['Row ID', 'Variation', 'Gone'])
        sheet.add_row(%w[__uuid __variation prop:layergonefieldgone], types: %i[string string string])
        sheet.add_row(['', '', ''], types: %i[string string string])
        sheet.add_row(['uuid-a', 'kept', 'x'], types: %i[string string string])
      end
      file = Tempfile.new(['unknown', '.xlsx'])
      file.binmode
      file.write(package.to_stream.read)
      file.flush

      result, importer = import(file, ElementVariationDoubles.record)

      expect(importer.warnings.join).to include('C (prop:layergonefieldgone)')
      expect(result.variations['uuid-a']['name']).to eq('kept')
    ensure
      file&.close!
    end
  end
end
