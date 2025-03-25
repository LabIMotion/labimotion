# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/labimotion/libs/xlsx_exporter'

RSpec.describe Labimotion::XlsxExporter do
  describe '#initialize' do
    it 'creates a new exporter without filename' do
      exporter = described_class.new
      expect(exporter).to be_a(described_class)
      expect(exporter.package).to be_a(Axlsx::Package)
      expect(exporter.workbook).to be_a(Axlsx::Workbook)
    end

    it 'creates a new exporter with filename' do
      exporter = described_class.new('test_report')
      expect(exporter.filename).to eq('test_report.xlsx')
    end
  end

  describe '#add_worksheet' do
    let(:exporter) { described_class.new('test') }

    it 'adds a worksheet' do
      sheet = exporter.add_worksheet('TestSheet')
      expect(sheet).to be_a(Labimotion::XlsxExporter::SheetBuilder)
    end

    it 'adds worksheet with block' do
      exporter.add_worksheet('TestSheet') do |sheet|
        sheet.add_header(%w[Col1 Col2])
        sheet.add_row(%w[Value1 Value2])
      end

      worksheet = exporter.workbook.worksheets.first
      expect(worksheet.name).to eq('TestSheet')
      expect(worksheet.rows.count).to eq(2)
    end
  end

  describe '#filename' do
    it 'returns filename with extension when name provided' do
      exporter = described_class.new('my_report')
      expect(exporter.filename).to eq('my_report.xlsx')
    end

    it 'generates filename with timestamp when no name provided' do
      exporter = described_class.new
      expect(exporter.filename).to match(/export_\d{8}_\d{6}\.xlsx/)
    end
  end

  describe '#to_stream and #read' do
    let(:exporter) { described_class.new('test') }

    before do
      exporter.add_worksheet('Sheet1') do |sheet|
        sheet.add_header(['Test'])
        sheet.add_row(['Data'])
      end
    end

    it 'returns a stream' do
      stream = exporter.to_stream
      expect(stream).to respond_to(:read)
    end

    it 'reads content' do
      content = exporter.read
      expect(content).to be_a(String)
      expect(content.length).to be > 0
      # Check for Excel file signature (ZIP format)
      expect(content[0..3]).to eq("PK\x03\x04")
    end
  end

  describe Labimotion::XlsxExporter::SheetBuilder do
    let(:exporter) { Labimotion::XlsxExporter.new('test') }
    let(:sheet_builder) do
      exporter.add_worksheet('TestSheet')
    end

    describe '#add_header' do
      it 'adds a header row' do
        sheet_builder.add_header(%w[Name Age Email])
        expect(sheet_builder.sheet.rows.count).to eq(1)
        expect(sheet_builder.sheet.rows.first.cells.map(&:value)).to eq(%w[Name Age Email])
      end

      it 'applies bold style to header' do
        sheet_builder.add_header(['Header'])
        # Style is applied, we just verify no errors
        expect(sheet_builder.sheet.rows.count).to eq(1)
      end
    end

    describe '#add_row' do
      it 'adds a data row' do
        sheet_builder.add_row(['John', 30, 'john@example.com'])
        expect(sheet_builder.sheet.rows.count).to eq(1)
        expect(sheet_builder.sheet.rows.first.cells.map(&:value)).to eq(['John', 30, 'john@example.com'])
      end

      it 'adds row with custom height' do
        sheet_builder.add_row(['Data'], height: 30)
        expect(sheet_builder.sheet.rows.first.height).to eq(30)
      end
    end

    describe '#add_rows' do
      it 'adds multiple rows' do
        rows = [
          ['Alice', 25],
          ['Bob', 30],
          ['Charlie', 35]
        ]
        sheet_builder.add_rows(rows)
        expect(sheet_builder.sheet.rows.count).to eq(3)
      end
    end

    describe '#add_blank_row' do
      it 'adds an empty row' do
        sheet_builder.add_header(['Test'])
        sheet_builder.add_blank_row
        sheet_builder.add_row(['Data'])
        expect(sheet_builder.sheet.rows.count).to eq(3)
        expect(sheet_builder.sheet.rows[1].cells).to be_empty
      end
    end

    describe '#set_column_widths' do
      it 'sets column widths' do
        sheet_builder.set_column_widths(10, 20, 30)
        # Verify no errors - actual width application happens during serialization
        expect { sheet_builder.set_column_widths(10, 20) }.not_to raise_error
      end
    end

    describe '#add_section' do
      it 'adds a section with title and data' do
        sheet_builder.add_section('Test Section', [
                                    %w[Key1 Value1],
                                    %w[Key2 Value2]
                                  ])
        # Section includes: blank row (if not first), title row, data rows, trailing blank row
        expect(sheet_builder.sheet.rows.count).to be >= 3
      end
    end

    describe '#freeze_panes' do
      it 'freezes panes at specified position' do
        sheet_builder.add_header(['Test'])
        expect { sheet_builder.freeze_panes(1, 0) }.not_to raise_error
      end
    end

    describe '#add_auto_filter' do
      it 'adds auto filter' do
        sheet_builder.add_header(%w[Col1 Col2])
        expect { sheet_builder.add_auto_filter }.not_to raise_error
      end

      it 'adds auto filter with custom range' do
        sheet_builder.add_header(%w[Col1 Col2])
        expect { sheet_builder.add_auto_filter('A1:B1') }.not_to raise_error
      end
    end

    describe '#merge_cells' do
      it 'merges cells' do
        sheet_builder.add_row(['Merged Content'])
        expect { sheet_builder.merge_cells('A1', 'C1') }.not_to raise_error
      end
    end
  end

  describe Labimotion::XlsxExporter::StyleManager do
    let(:exporter) { Labimotion::XlsxExporter.new('test') }
    let(:sheet_builder) { exporter.add_worksheet('TestSheet') }
    let(:style_manager) { sheet_builder.styles }

    describe '#create_style' do
      it 'creates a style with options' do
        style = style_manager.create_style(bold: true, bg_color: 'DDDDDD')
        expect(style).to be_a(Integer) # Style reference
      end

      it 'caches styles' do
        style1 = style_manager.create_style(bold: true)
        style2 = style_manager.create_style(bold: true)
        expect(style1).to eq(style2)
      end
    end

    describe 'predefined styles' do
      it 'provides header style' do
        style = style_manager.header_style
        expect(style).to be_a(Integer)
      end

      it 'provides currency style' do
        style = style_manager.currency_style
        expect(style).to be_a(Integer)
      end

      it 'provides percentage style' do
        style = style_manager.percentage_style
        expect(style).to be_a(Integer)
      end

      it 'provides date style' do
        style = style_manager.date_style
        expect(style).to be_a(Integer)
      end

      it 'provides datetime style' do
        style = style_manager.datetime_style
        expect(style).to be_a(Integer)
      end
    end
  end

  describe 'integration test' do
    it 'creates a complete Excel file' do
      exporter = described_class.new('integration_test')

      exporter.add_worksheet('Data') do |sheet|
        sheet.add_header(%w[Name Age Email])
        sheet.add_rows([
                         ['Alice', 25, 'alice@example.com'],
                         ['Bob', 30, 'bob@example.com']
                       ])
        sheet.freeze_panes(1, 0)
        sheet.add_auto_filter
      end

      exporter.add_worksheet('Summary') do |sheet|
        sheet.add_section('Summary', [
                            ['Total Records', 2],
                            ['Average Age', 27.5]
                          ])
      end

      content = exporter.read
      expect(content).to be_a(String)
      expect(content.length).to be > 0
      expect(exporter.workbook.worksheets.count).to eq(2)
    end
  end
end
