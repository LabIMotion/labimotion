# frozen_string_literal: true

require 'caxlsx'
require 'roo'
require 'securerandom'
require 'labimotion/libs/element_variation_column_set'

module Labimotion
  ## ImportElementVariations
  # Reads an .xlsx workbook produced by ExportElementVariations back into an
  # element's variations.
  #
  # Rows are merged by uuid: a sheet row updates only the columns the sheet
  # actually carries, variations absent from the sheet are left untouched, and a
  # row with a blank `__uuid` becomes a new variation. A wholesale replace would
  # silently drop data held in columns the user had not selected when exporting.
  class ImportElementVariations
    SHEET_NAME = 'Variations'
    # The machine key row is found by its `__uuid` cell rather than fixed at a
    # row number, so a workbook from an older export -- whose header was one row
    # instead of three -- still imports.
    KEY_ROW_SEARCH_LIMIT = 8
    MULTI_VALUE_SEPARATOR = ';'
    GROUP_DISALLOWED = /[^a-zA-Z0-9_\-.,\s]/
    GROUP_MAX_LENGTH = 64
    # A cell whose value a column cannot hold. Treated like a blank cell: it
    # clears what the column held, but never adds a value that was not there.
    REJECTED = Object.new.freeze

    class InvalidWorkbook < StandardError; end

    def initialize(element, file_path, segment_klasses: nil, record: nil)
      @element = element
      @file_path = file_path
      @segment_klasses = segment_klasses
      @record = record
      @warnings = []
    end

    attr_reader :element, :file_path, :warnings

    def execute!
      sheet = open_sheet
      mapping = build_column_mapping(sheet)
      parsed_rows = parse_rows(sheet, mapping)
      persist(parsed_rows)
    end

    private

    def record
      @record ||= Labimotion::ElementVariation.find_or_initialize_by(element_id: element.id)
    end

    def column_set
      @column_set ||= Labimotion::ElementVariationColumnSet.new(
        element, record, segment_klasses: @segment_klasses
      )
    end

    # ---- workbook reading -------------------------------------------------

    def open_sheet
      workbook = Roo::Spreadsheet.open(file_path, extension: :xlsx)
      unless workbook.sheets.include?(SHEET_NAME)
        raise InvalidWorkbook, "Sheet '#{SHEET_NAME}' not found. Use a file produced by the variations export."
      end

      workbook.sheet(SHEET_NAME)
    rescue Roo::Error, Zip::Error, IOError => e
      raise InvalidWorkbook, "Cannot read the file as .xlsx: #{e.message}"
    end

    # The machine key row is immediately followed by the unit row, and the data
    # starts after it. Both are hidden in the exported workbook.
    def key_row(sheet)
      @key_row ||= begin
        limit = [sheet.last_row.to_i, KEY_ROW_SEARCH_LIMIT].min
        found = (1..limit).find do |number|
          Array(sheet.row(number)).any? do |cell|
            cell.to_s.strip == Labimotion::ElementVariationColumnSet::UUID_KEY
          end
        end
        found || raise(
          InvalidWorkbook,
          "No column key row found: none of the first #{KEY_ROW_SEARCH_LIMIT} rows carries a " \
          "'#{Labimotion::ElementVariationColumnSet::UUID_KEY}' cell. " \
          'Use a file produced by the variations export.'
        )
      end
    end

    # Column index -> { key:, unit: }.
    def build_column_mapping(sheet)
      keys = safe_row(sheet, key_row(sheet))
      units = safe_row(sheet, key_row(sheet) + 1)

      mapping = {}
      keys.each_with_index do |key, index|
        key = key.to_s.strip
        next if key.empty?

        mapping[index] = { key: key, unit: units[index].to_s.strip }
      end

      validate_mapping!(mapping, key_row(sheet))
      warn_unknown_keys(mapping)
      mapping
    end

    def warn_unknown_keys(mapping)
      unknown = mapping.reject { |_index, column| known_key?(column[:key]) }
      return if unknown.empty?

      named = unknown.map { |index, column| "#{column_ref(index)} (#{column[:key]})" }
      @warnings << "Ignored unknown column(s) #{named.join(', ')} - the element schema may have " \
                   'changed since this file was exported.'
    end

    def known_key?(key)
      key == Labimotion::ElementVariationColumnSet::UUID_KEY || !column_set.lookup(key).nil?
    end

    def validate_mapping!(mapping, key_row_number)
      keys = mapping.values.map { |column| column[:key] }
      missing = [
        Labimotion::ElementVariationColumnSet::UUID_KEY,
        Labimotion::ElementVariationColumnSet::NAME_KEY
      ] - keys
      return if missing.empty?

      raise InvalidWorkbook,
            "Row #{key_row_number} is missing the column keys #{missing.join(', ')}. " \
            'Use a file produced by the variations export.'
    end

    def safe_row(sheet, number)
      return [] if sheet.last_row.nil? || sheet.last_row < number

      Array(sheet.row(number))
    end

    def parse_rows(sheet, mapping)
      last_row = sheet.last_row.to_i
      first_data_row = key_row(sheet) + 2
      return [] if last_row < first_data_row

      (first_data_row..last_row).filter_map do |number|
        cells = Array(sheet.row(number))
        next if cells.all? { |cell| blank_cell?(cell) }

        parse_row(cells, mapping, number)
      end
    end

    # Each cell carries the spreadsheet reference it came from, so a warning can
    # point the user at the cell to fix rather than just naming the bad value.
    def parse_row(cells, mapping, row_number)
      parsed = { uuid: nil, cells: {} }
      mapping.each do |index, column|
        value = cells[index]
        if column[:key] == Labimotion::ElementVariationColumnSet::UUID_KEY
          parsed[:uuid] = blank_cell?(value) ? nil : cell_to_s(value)
        else
          parsed[:cells][column[:key]] =
            { value: value, unit: column[:unit], ref: cell_ref(index, row_number) }
        end
      end
      parsed
    end

    # 0-based column index to the A1 notation a spreadsheet app shows.
    def column_ref(column_index)
      Axlsx.col_ref(column_index)
    end

    def cell_ref(column_index, row_number)
      "#{column_ref(column_index)}#{row_number}"
    end

    # ---- merging ----------------------------------------------------------

    def persist(parsed_rows)
      variations = deep_dup(record.variations_hash)
      row_order = []

      parsed_rows.each do |parsed|
        uuid = parsed[:uuid] || SecureRandom.uuid
        base = variations[uuid] || empty_row(uuid)
        variations[uuid] = merge_row(base, parsed[:cells], uuid)
        row_order << uuid
      end

      record.variations = variations
      apply_row_order(row_order, variations.keys)
      record.save!
      record
    end

    def apply_row_order(row_order, all_uuids)
      return unless record.respond_to?(:layout=)
      return unless record.class.respond_to?(:column_names) && record.class.column_names.include?('layout')

      layout = deep_dup(record.layout_hash)
      layout['rowOrder'] = row_order + (all_uuids - row_order)
      record.layout = layout
    end

    def empty_row(uuid)
      {
        'uuid' => uuid,
        'name' => 'Variation',
        'properties' => {},
        'metadata' => { 'notes' => '', 'analyses' => [], 'group' => '' },
        'segments' => {}
      }
    end

    def merge_row(base, cells, uuid)
      row = deep_dup(base)
      row['uuid'] = uuid
      row['properties'] ||= {}
      row['metadata'] ||= {}
      row['segments'] ||= {}

      cells.each do |key, cell|
        column = column_set.lookup(key)
        next if column.nil?

        apply_cell(row, column, cell)
      end
      row
    end

    def apply_cell(row, column, cell)
      case column.kind
      when :name then row['name'] = blank_cell?(cell[:value]) ? row['name'] : cell_to_s(cell[:value])
      when :property then apply_property(row, column, cell)
      when :metadata then apply_metadata(row, column, cell)
      when :segment then apply_segment(row, column, cell)
      end
    end

    def apply_property(row, column, cell)
      key = column.key.sub(/\Aprop:/, '')
      existing = row['properties'][key]

      # A blank cell for a property the row never had is not a deletion.
      return if existing.nil? && blank_cell?(cell[:value])

      value = if analyses_field?(column.field_type)
                analysis_ids(cell[:value], cell[:ref])
              else
                coerce_in(cell, column)
              end
      if value.equal?(REJECTED)
        return if existing.nil? # never stored, so there is nothing to clear

        value = nil
      end

      base_cell = existing.is_a?(Hash) ? existing : {}
      row['properties'][key] = base_cell.merge('value' => value, 'unit' => cell[:unit])
    end

    def apply_metadata(row, column, cell)
      field = column.key.sub(/\Ameta:/, '')
      row['metadata'][field] =
        case field
        when 'analyses' then analysis_ids(cell[:value], cell[:ref])
        when 'group' then sanitize_group(cell[:value])
        else blank_cell?(cell[:value]) ? '' : cell_to_s(cell[:value])
        end
    end

    def apply_segment(row, column, cell)
      _, klass_id, field_key = column.key.split(':', 3)
      snapshot = row['segments'][klass_id.to_s]
      return if snapshot.nil? && blank_cell?(cell[:value])

      value = coerce_in(cell, column)
      if value.equal?(REJECTED)
        return if snapshot.nil? # never stored, so there is nothing to clear

        value = nil
      end

      snapshot ||= {}
      snapshot[field_key] = value
      row['segments'][klass_id.to_s] = snapshot
    end

    # ---- value coercion ---------------------------------------------------

    def coerce_in(cell, column)
      value = cell[:value]
      return nil if blank_cell?(value)

      case column.field_type.to_s
      when 'integer' then to_integer(cell, column)
      when 'number', 'system-defined' then to_number(cell, column)
      when 'select-multi' then split_multi(value)
      else cell_to_s(value)
      end
    end

    def to_integer(cell, column)
      float = numeric(cell[:value])
      return reject(cell, column, 'takes numbers only') if float.nil?
      return reject(cell, column, 'takes whole numbers only') unless (float % 1).zero?

      float.to_i
    end

    # xlsx has a single numeric type, so a stored 1.0 comes back as 1. Normalise
    # integral values to Integer rather than leave the result depending on how
    # the spreadsheet happened to round-trip the cell.
    def to_number(cell, column)
      float = numeric(cell[:value])
      return reject(cell, column, 'takes numbers only') if float.nil?

      (float % 1).zero? ? float.to_i : float
    end

    # Strict: "12abc" is not a number. A single comma reads as the decimal
    # separator. Kept in step with coerceFieldValue in the React grid, so a cell
    # cannot mean one thing there and another here.
    def numeric(value)
      return value.to_f if value.is_a?(Numeric)

      Float(value.to_s.strip.sub(',', '.'))
    rescue ArgumentError, TypeError
      nil
    end

    # A numeric column holds a number or nothing at all. The text is not stored,
    # and whatever the column held before is cleared: keeping it would leave the
    # grid showing the very value the warning says was not accepted -- and that
    # value may itself be text, from before these columns were checked.
    def reject(cell, column, reason)
      @warnings << "Cell #{cell[:ref]}: cleared '#{cell_to_s(cell[:value])}' - " \
                   "#{column.label} #{reason}."
      REJECTED
    end

    def split_multi(value)
      return value if value.is_a?(Array)

      cell_to_s(value).split(MULTI_VALUE_SEPARATOR).map(&:strip).reject(&:empty?)
    end

    def analyses_field?(field_type)
      field_type.to_s == Labimotion::ElementVariationColumnSet::ANALYSES_FIELD
    end

    def analysis_ids(value, ref)
      return [] if blank_cell?(value)

      ids = split_multi(value).filter_map do |token|
        Integer(token)
      rescue ArgumentError, TypeError
        @warnings << "Cell #{ref}: ignored non-numeric analysis reference '#{token}'."
        nil
      end

      known, unknown = ids.partition { |id| element_analysis_ids.include?(id) }
      unless unknown.empty?
        @warnings << "Cell #{ref}: ignored analysis id(s) #{unknown.join(', ')} - " \
                     'they do not belong to this element.'
      end
      known
    end

    def element_analysis_ids
      @element_analysis_ids ||= begin
        element.respond_to?(:analyses) ? Array(element.analyses).map(&:id) : []
      rescue StandardError
        []
      end
    end

    def sanitize_group(value)
      return '' if blank_cell?(value)

      cell_to_s(value).gsub(GROUP_DISALLOWED, '')[0, GROUP_MAX_LENGTH].to_s
    end

    # ---- cell helpers -----------------------------------------------------

    def blank_cell?(value)
      value.nil? || (value.is_a?(String) && value.strip.empty?)
    end

    # Roo hands back Floats for anything numeric-looking, so an integral value
    # from a text column would otherwise stringify as "12.0".
    def cell_to_s(value)
      return value if value.is_a?(String)
      return format('%d', value) if value.is_a?(Float) && (value % 1).zero?

      value.to_s
    end

    def deep_dup(value)
      case value
      when Hash then value.each_with_object({}) { |(key, val), acc| acc[key] = deep_dup(val) }
      when Array then value.map { |item| deep_dup(item) }
      else value
      end
    end
  end
end
