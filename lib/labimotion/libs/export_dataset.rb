# frozen_string_literal: true
require 'export_table'
require 'labimotion/version'

module Labimotion
  ## ExportDataset
  class ExportDataset
    DEFAULT_ROW_WIDTH = 100
    DEFAULT_ROW_HEIGHT = 20

    def initialize(id)
      @xfile = Axlsx::Package.new
      @xfile.workbook.styles.fonts.first.name = 'Calibri'
      @file_extension = 'xlsx'

      @id = id
      @dataset = Labimotion::Dataset.find_by(element_id: @id, element_type: 'Container')
      return if @dataset.nil?

      @klass = @dataset.dataset_klass
      @ols_term_id = @klass.ols_term_id
      @label = @klass.label
      @analysis = @dataset&.element&.parent
      @element = @analysis&.root&.containable if @analysis.present?
      @element_type = @element.class.name if @element.present?
      @spectra_values = []
    end

    def read
      @xfile.to_stream.read
    end

    def res_name
      element_name = Container.find(@id)&.root_element&.short_label
      ols = ols_name
      "#{element_name}_#{ols.gsub(' ', '_')}.xlsx"
    rescue StandardError => e
      Labimotion.log_exception(e)
    end

    def export
      return if @dataset.nil? || @analysis.nil? || @element.nil?

      description
      dataset_info
      spectra_info
      chemwiki_info
    rescue StandardError => e
      Labimotion.log_exception(e)
    end

    private

    def chemwiki_info
      @spectra_values
      config = Labimotion::MapperUtils.load_config(File.read(Constants::Mapper::WIKI_CONFIG))
      return if config.nil? || config[@ols_term_id].nil?

      sheet = @xfile.workbook.add_worksheet(name: 'ChemWiki')
      map_index = config.dig(@ols_term_id, 'index')
      map_mapper = config.dig(@ols_term_id, 'mapper')
      map_source = config.dig(@ols_term_id, 'source')

      return if map_index.nil? || map_mapper.nil? || map_source.nil?

      return unless map_index.is_a?(Array) && map_mapper.is_a?(Hash) && map_source.is_a?(Hash)

      # sheet.column_info.each { |col| col.width = map_width }

      if @spectra_values.length == 0
        @spectra_values.push([])
      end

      @spectra_values.each_with_index do |spdata, idx|
        array_header = []
        array_data = []
        map_index.each do |key|
          mapper = map_mapper.dig(key)
          next if mapper.nil? || mapper['sources'].nil? || !mapper.is_a?(Hash)

          col_header = ''
          col_value = ''
          mapper['sources'].each_with_index do |source_key, idx|
            source = map_source&.dig(source_key)
            next if source.nil? || source['title'].nil?

            col_header = source['title']

            if col_value.present?
              col_value += (mapper['separator'] || '') + source_data(source, spdata)
            else
              col_value = source_data(source, spdata)
            end
          end
          array_header.push(col_header || '')
          array_data.push(col_value || '')
        end
        if idx == 0
          sheet.add_row(array_header)
        end
        sheet.add_row(array_data)

        ## for Redox potential
        last_row = sheet.rows.last
        last_row.cells[3].type = :string
      end


    rescue StandardError => e
      Labimotion.log_exception(e)
    end


    def conv_value(field, properties)
      return '' if field.nil?

      case field['type']
      when 'select'
        return '' if field['value'].empty?
        Labimotion::Utils.find_options_val(field, properties) || field['value']
      else
        field['value']
      end
    end

    def source_data(source, spdata)
      param = source['param']
      return '' if param.nil? || source['type'].nil?

      val = case source['type']
            when 'string'
              param
            when 'spc'
              spdata.length.positive? && param.is_a?(Integer) ? spdata.pluck(param).join(';') : ''
            when 'sample'
              @element.send(param) if @element.respond_to?(param)
            when 'molecule'
              @element.molecule.send(param) if @element_type == 'Sample' && @element&.molecule&.respond_to?(param)
            when 'dataset'
              field = Labimotion::Utils.find_field(@dataset.properties, param)
              conv_value(field, @dataset.properties)
            end
      val || ''
    rescue StandardError => e
      Labimotion.log_exception(e)
    end

    def element_info
      if @element.class.name == 'Sample'
        sheet = @xfile.workbook.add_worksheet(name: 'Element')
        sheet.add_row(['inchikey', @element.molecule_inchikey])
        sheet.add_row(['molfile', @element.molfile])
      end
    rescue StandardError => e
      Labimotion.log_exception(e)
    end

    def ols_name
      match = @label.match(/\((.*?)\)/)
      name = match && match.length > 1 ? match[1] : @label

      name = '1H NMR' if @ols_term_id == 'CHMO:0000593'
      name = '13C NMR' if @ols_term_id == 'CHMO:0000595'
      name.slice(0, 26)
    rescue StandardError => e
      Labimotion.log_exception(e)
      'ols_name'
    end

    def description
      sheet = @xfile.workbook.add_worksheet(name: 'Description')
      header_style = sheet.styles.add_style(sz: 12, fg_color: 'FFFFFF', bg_color: '00008B', border: { style: :thick, color: 'FF777777', edges: [:bottom] })
      sheet.add_row(['File name', res_name])
      sheet.add_row(['Time', Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")] )
      sheet.add_row(['(This file is automatically generated by the system.)'])
      sheet.add_row([''])
      sheet.add_row([''])
      sheet.add_row(['Fields description of sheet:' + @dataset.dataset_klass.label])
      sheet.add_row(['Fields', 'Field description'], style: header_style)
      sheet.add_row(['Layer Label', 'The label of the layer'])
      sheet.add_row(['Field Label', 'The label of the field'])
      sheet.add_row(['Value', 'The current value of the field'])
      sheet.add_row(['Unit', 'The unit of the field'])
      sheet.add_row(['Name', 'The key of the field, can be used to identify the field'])
      sheet.add_row(['Type', 'The type of the field'])
      sheet.add_row(['Source?', '[Device] from device, [Chemotion] from Chemotion'])
      sheet.add_row(['Source identifier', 'The source identifier'])
      sheet.add_row(['Source data', 'The data from Device or Chemotion, cannot be modified once a generic dataset is created'])
      sheet.add_row([''])
      sheet.add_row([''])
    rescue StandardError => e
      Labimotion.log_exception(e)
    end

    def dataset_info
      name = ols_name
      return if name.nil?

      sheet = create_dataset_sheet(name)
      process_layers(sheet)
    rescue StandardError => e
      Labimotion.log_exception(e)
    end

    def create_dataset_sheet(name)
      sheet = @xfile.workbook.add_worksheet(name: name)
      sheet.add_row([@dataset.dataset_klass.label])
      sheet.add_row(header, style: create_header_style(sheet))
      sheet
    end

    def process_layers(sheet)
      layers = @dataset.properties[Labimotion::Prop::LAYERS] || {}
      options = @dataset.properties[Labimotion::Prop::SEL_OPTIONS]

      sort_layers(layers).each do |key|
        layer = layers[key]
        add_layer_row(sheet, layer)
        process_fields(sheet, layer, options)
      end
    end

    def sort_layers(layers)
      layers.keys.sort_by { |key| layers[key]['position'] }
    end

    def add_layer_row(sheet, layer)
      layer_style = sheet.styles.add_style(b: true, bg_color: 'CEECF5')
      sheet.add_row([layer['label']] + [' '] * 8, style: layer_style)
    end

    def process_fields(sheet, layer, options)
      sorted_fields = sort_fields(layer)

      sorted_fields.each do |field|
        next if field['type'] == 'dummy'

        add_field_row(sheet, field)
        set_field_types(sheet, field, options)
      end
    end

    def sort_fields(layer)
      layer[Labimotion::Prop::FIELDS].sort_by { |obj| obj['position'] }
    end

    def add_field_row(sheet, field)
      type = determine_field_type(field)
      from_device = determine_source(field)
      show_value = format_value(field['value'])
      ontology_data = extract_ontology_data(field)

      row_data = [
        ' ',
        field['label'],
        nil,
        field['value_system'],
        field['field'],
        type,
        from_device,
        field['dkey'],
        nil
      ] + ontology_data

      sheet.add_row(row_data.freeze)
    end

    def determine_field_type(field)
      return "#{field['type']}-#{field['option_layers']}" if [
        Labimotion::FieldType::SELECT,
        Labimotion::FieldType::SYSTEM_DEFINED
      ].include?(field['type'])

      field['type']
    end

    def determine_source(field)
      return 'Chemotion' if field['system'].present?
      return 'Device' if field['device'].present?
      ''
    end

    def format_value(value)
      return value&.gsub(',', '.') if value =~ /\A\d+,\d+\z/
      value
    end

    def extract_ontology_data(field)
      ontology = field['ontology'] || {}
      [
        ontology['short_form'] || '',
        ontology['label'] || '',
        ontology['iri'] || ''
      ]
    end

    def set_field_types(sheet, field, options)
      last_row = sheet.rows.last

      case field['type']
      when Labimotion::FieldType::SELECT
        set_select_field_type(last_row, field, options)
      when Labimotion::FieldType::SYSTEM_DEFINED, Labimotion::FieldType::INTEGER
        set_numeric_field_type(last_row)
      else
        set_string_field_type(last_row)
      end

      set_field_values(last_row, field)
    end

    def set_select_field_type(row, field, options)
      row.cells[2].type = :string
      row.cells[8].type = :string
      row.cells[2].value = opt_value(field, options) if field['value'].present?
    end

    def set_numeric_field_type(row)
      row.cells[2].type = :float
      row.cells[8].type = :float
    end

    def set_string_field_type(row)
      row.cells[2].type = :string
      row.cells[8].type = :string
    end

    def set_field_values(row, field)
      row.cells[8].value = field['system'] || field['device']
    end

    def spectra_info
      name_mapping = process_csv_files
      return if name_mapping.nil? || name_mapping.length <= 1

      create_mapping_sheet(name_mapping)
    rescue StandardError => e
      Labimotion.log_exception(e)
    end

    def process_csv_files
      cds_csv = Container.find(@id).attachments.where(aasm_state: 'csv').order(:filename)
      return if cds_csv.empty?

      cds_csv.each_with_index.map do |att, index|
        process_single_csv(att, index)
      end.compact
    end

    def process_single_csv(attachment, index)
      sheet_name = "Sheet#{index + 1}"
      sheet = @xfile.workbook.add_worksheet(name: sheet_name)

      File.open(attachment.attachment_url) do |file|
        first_line = file.readline.chomp
        next unless cv_spc?(first_line)

        process_csv_content(first_line, file, sheet)
      end
      [sheet_name, attachment.filename]
    end

    def process_csv_content(first_line, file, sheet)
      lines = []
      file.each_line.with_index do |line, index|
        line = first_line if index.zero?
        row_data = line.split(',')
        sheet.add_row(row_data)
        lines << row_data if cv_data?(row_data, index)
      end
      @spectra_values << lines if lines.any?
    end

    def create_mapping_sheet(name_mapping)
      first_sheet = @xfile.workbook.worksheets&.first
      return unless first_sheet

      header_style = create_header_style(first_sheet)
      first_sheet.add_row(['Sheet name', 'File name'], style: header_style)

      name_mapping.each do |sheet_name, filename|
        first_sheet.add_row([sheet_name.to_s, filename.to_s])
      end
    end


    def create_header_style(sheet)
      sheet.styles.add_style(
        sz: 12,
        fg_color: 'FFFFFF',
        bg_color: '00008B',
        border: {
          style: :thick,
          color: 'FF777777',
          edges: [:bottom]
        }
      )
    end

    def opt_value(field, options)
      return nil if field.nil? || options.nil? || field['value']&.empty? || field['option_layers']&.empty?
      return nil unless opts = options.fetch(field['option_layers'], nil)&.fetch('options', nil)

      selected = opts&.find { |ss| ss['key'] == field['value'] }
      selected&.fetch('label', nil) || field['value']
    rescue StandardError => e
      Labimotion.log_exception(e)
      field['value']
    end

    def cv_spc?(first_line)
      data = first_line.split(',')
      data && data.length > 2 && data[2] == Constants::CHMO::CV
    end

    def cv_data?(data, idx)
      data.length > 7 && idx > 7
    end

    def header
      ['Layer Label', 'Field Label', 'Value', 'Unit', 'Name', 'Type', 'Source?', 'Source identifier', 'Source data', 'Ontology', 'Ontology Label', 'iri'].freeze
    end

  end
end
