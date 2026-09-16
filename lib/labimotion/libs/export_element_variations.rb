# frozen_string_literal: true

require 'labimotion/libs/xlsx_exporter'
require 'labimotion/libs/element_variation_column_set'
require 'labimotion/libs/element_variation_header'

module Labimotion
  ## ExportElementVariations
  # Writes a generic element's variations to an .xlsx workbook that
  # ImportElementVariations can read back. See ImportElementVariations for the
  # inverse.
  #
  # Sheet `Variations`:
  #   row 1  group header      (Properties / Metadata / Segments)
  #   row 2  sub-group header  (layer or segment name)
  #   row 3  leaf header       (field label, with its unit token)
  #   row 4  machine column keys               (hidden)
  #   row 5  unit token per column             (hidden)
  #   row 6+ one row per variation
  #
  # Rows 1-3 mirror the banded header the React grid draws, merged the same way:
  # a header with no level below it spans down to row 3. Rows 4 and 5 are what
  # make the export re-importable; they are hidden so a user only ever sees the
  # header and the data.
  class ExportElementVariations
    SHEET_NAME = 'Variations'
    INFO_SHEET_NAME = 'Info'
    SCHEMA_VERSION = 2
    HEADER_ROWS = Labimotion::ElementVariationHeader::ROWS
    KEY_ROW = HEADER_ROWS + 1
    UNIT_ROW = HEADER_ROWS + 2
    MULTI_VALUE_SEPARATOR = '; '
    GROUP_HEADER_BG = 'C5D9F1'
    SUB_GROUP_HEADER_BG = 'DCE6F1'

    # `system-defined` is the unit-bearing numeric field type.
    NUMERIC_FIELD_TYPES = %w[integer number system-defined].freeze
    MULTI_VALUE_FIELD_TYPES = %w[select-multi].freeze

    def initialize(element, variation: nil, user: nil, segment_klasses: nil)
      @element = element
      @variation = variation || element.element_variation
      @user = user
      @column_set = Labimotion::ElementVariationColumnSet.new(
        element, @variation, segment_klasses: segment_klasses
      )
    end

    attr_reader :element, :variation, :user, :column_set

    def read
      exporter.read
    end

    def to_stream
      exporter.to_stream
    end

    def filename
      exporter.filename
    end

    private

    def exporter
      @exporter ||= begin
        xlsx = Labimotion::XlsxExporter.new(base_filename)
        build_variations_sheet(xlsx)
        build_info_sheet(xlsx)
        xlsx
      end
    end

    def base_filename
      short_label = element.respond_to?(:short_label) ? element.short_label.to_s : ''
      short_label = element.name.to_s if short_label.empty?
      short_label = "element_#{element.id}" if short_label.empty?
      "#{short_label}_variations_#{Time.now.strftime('%Y%m%d_%H%M%S')}".gsub(/\s+/, '_')
    end

    def columns
      @columns ||= column_set.columns
    end

    def header
      @header ||= Labimotion::ElementVariationHeader.new(columns)
    end

    def build_variations_sheet(xlsx)
      # Without a block, add_worksheet just hands back the SheetBuilder; taking
      # it that way avoids the block's instance_eval and its locals-only rule.
      sheet = xlsx.add_worksheet(SHEET_NAME)
      write_header(sheet)
      write_machine_rows(sheet)
      write_data_rows(sheet)
      sheet.freeze_panes(UNIT_ROW, 2)
      header.merges.each { |from, to| sheet.merge_cells(from, to) }
      hide_machine_rows(sheet.sheet)
    end

    def write_header(sheet)
      group_row, sub_group_row, leaf_row = header.rows
      sheet.add_header(group_row, bg_color: GROUP_HEADER_BG, alignment: :center)
      sheet.add_header(sub_group_row, bg_color: SUB_GROUP_HEADER_BG, alignment: :center)
      sheet.add_header(leaf_row)
    end

    def write_machine_rows(sheet)
      text_types = columns.map { :string }
      sheet.add_row(columns.map(&:key), types: text_types)
      sheet.add_row(columns.map(&:unit), types: text_types)
    end

    def write_data_rows(sheet)
      column_set.rows.each do |row|
        values = serialize_row(row)
        sheet.add_row(values, types: cell_types(values))
      end
    end

    # Axlsx infers a cell's type from its value, which would turn the group
    # "1.10" into the number 1.1 and an analysis id list "101" into 101. Pin
    # everything the serializer produced as a String to :string; leave the
    # genuinely numeric cells on auto-detection.
    def cell_types(data_row)
      data_row.map { |value| value.is_a?(Numeric) ? nil : :string }
    end

    # SheetBuilder exposes no row-hiding helper; reach through to the Axlsx row.
    def hide_machine_rows(worksheet)
      [KEY_ROW - 1, UNIT_ROW - 1].each { |index| worksheet.rows[index].hidden = true }
    end

    def build_info_sheet(xlsx)
      info = info_rows
      analyses = analyses_rows

      xlsx.add_worksheet(INFO_SHEET_NAME) do |sheet|
        sheet.add_section('Element', info)
        sheet.add_header(['Analysis ID', 'Name', 'Kind'])
        analyses.each { |analysis_row| sheet.add_row(analysis_row) }
        sheet.auto_fit_columns
      end
    end

    def info_rows
      rows = [
        ['Element ID:', element.id],
        ['Short label:', element.respond_to?(:short_label) ? element.short_label : nil],
        ['Element class:', element_klass_label],
        ['Exported at:', Time.now.strftime('%Y-%m-%d %H:%M:%S')]
      ]
      rows << ['Exported by:', user.name] if user.respond_to?(:name)
      rows << ['Schema version:', SCHEMA_VERSION]
      rows
    end

    def element_klass_label
      klass = element.respond_to?(:element_klass) ? element.element_klass : nil
      return nil if klass.nil?

      klass.respond_to?(:label) && !klass.label.to_s.empty? ? klass.label : klass.name
    end

    def analyses_rows
      element_analyses.map do |analysis|
        kind = analysis.respond_to?(:extended_metadata) ? (analysis.extended_metadata || {})['kind'] : nil
        [analysis.id, analysis.name, kind]
      end
    end

    def element_analyses
      return [] unless element.respond_to?(:analyses)

      Array(element.analyses)
    rescue StandardError
      []
    end

    # ---- cell serialization ----------------------------------------------

    def serialize_row(row)
      columns.map { |column| serialize_cell(column, row) }
    end

    def serialize_cell(column, row)
      case column.kind
      when :uuid then row['uuid'].to_s
      when :name then row['name'].to_s
      when :property then serialize_property(column, row)
      when :metadata then serialize_metadata(column, row)
      when :segment then serialize_segment(column, row)
      end
    end

    def serialize_property(column, row)
      key = column.key.sub(/\Aprop:/, '')
      cell = (row['properties'] || {})[key]
      return nil unless cell.is_a?(Hash)

      coerce_out(cell['value'], column.field_type)
    end

    def serialize_metadata(column, row)
      field = column.key.sub(/\Ameta:/, '')
      value = (row['metadata'] || {})[field]
      field == 'analyses' ? join_multi(value) : coerce_out(value, field)
    end

    def serialize_segment(column, row)
      _, klass_id, field_key = column.key.split(':', 3)
      value = row.dig('segments', klass_id.to_s, field_key)
      coerce_out(value, column.field_type)
    end

    def coerce_out(value, field_type)
      return nil if value.nil? || value == ''
      return join_multi(value) if value.is_a?(Array)
      return numeric_or_raw(value) if NUMERIC_FIELD_TYPES.include?(field_type.to_s)
      return join_multi(value) if MULTI_VALUE_FIELD_TYPES.include?(field_type.to_s)

      value.is_a?(String) ? value : value.to_s
    end

    def join_multi(value)
      return nil if value.nil?
      return nil if value.is_a?(Array) && value.empty?
      return value.join(MULTI_VALUE_SEPARATOR) if value.is_a?(Array)

      value.to_s
    end

    # Write numbers as numbers so a spreadsheet app treats them as such; fall
    # back to the raw string when the stored value is not actually numeric.
    def numeric_or_raw(value)
      return value if value.is_a?(Numeric)

      text = value.to_s.strip
      float = Float(text)
      (float % 1).zero? && !text.include?('.') ? float.to_i : float
    rescue ArgumentError, TypeError
      value.to_s
    end
  end
end
