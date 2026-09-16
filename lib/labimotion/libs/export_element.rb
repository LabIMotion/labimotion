# frozen_string_literal: true
require 'date'
require 'ostruct'
require 'export_table'
require 'labimotion/version'
require 'labimotion/utils/units'
require 'sablon'

module Labimotion
  class ExportElement
    def initialize(current_user, element, export_format)
      @current_user = current_user
      @element = element
      @parent =
        case element.class.name
        when 'Labimotion::Segment'
          element&.element
        when 'Labimotion::Dataset'
          element&.element&.root_element
        end
      @element_klass =
        case element.class.name
        when 'Labimotion::Element'
          element.element_klass
        when 'Labimotion::Segment'
          element.segment_klass
        when 'Labimotion::Dataset'
          element.dataset_klass
        end
      @name = @element.instance_of?(Labimotion::Element) ? element.name : @parent&.name
      @short_label = @element.instance_of?(Labimotion::Element) ? element.short_label : @parent&.short_label
      @element_name = "#{@element_klass.label}_#{@short_label}".gsub(/\s+/, '')
      @properties = element.properties
      @options = element.properties_release[Labimotion::Prop::SEL_OPTIONS]
      @export_format = export_format
    rescue StandardError => e
      Labimotion.log_exception(e)
    end

    def sample_url
      host = ENV['PUBLIC_URL'] || 'http://localhost:3000'
      api = 'mydb/collection/all/sample'
      "#{host}/#{api}"
    end

    def build_layers
      objs = []
      @properties[Labimotion::Prop::LAYERS]&.keys&.sort_by do |key|
        [
          @properties[Labimotion::Prop::LAYERS].fetch(key, nil)&.fetch('position', 0) || 0,
          @properties[Labimotion::Prop::LAYERS].fetch(key, nil)&.fetch('wf_position', 0) || 0
        ]
      end&.each do |key|
        layer = @properties[Labimotion::Prop::LAYERS][key] || {}

        ## Build fields html
        # field_objs = build_fields_html(layer) if layer[Labimotion::Prop::FIELDS]&.length&.positive?
        # field_html = Sablon.content(:html, field_objs) if field_objs.present?
        field_objs = build_fields(layer)

        layer_info = {
          label: layer['label'],
          layer: layer['layer'],
          cols: layer['cols'],
          timeRecord: layer['timeRecord'],
          fields: field_objs
        }
        objs.push(layer_info)
      end
      objs
    rescue StandardError => e
      Labimotion.log_exception(e)
    end

    def build_field(layer, field)
      field_obj = {}
      field_obj[:label] = field['label']
      field_obj[:field] = field['field']
      field_obj[:type] = field['type']

      field_obj.merge!(field.slice('value', 'value_system'))
      field_obj[:is_table] = false
      field_obj[:not_table] = true
      case field['type']
      when Labimotion::FieldType::DRAG_ELEMENT
        field_obj[:value] = (field['value'] && field['value']['el_label']) || ''
        field_obj[:obj] = field['value']  ### change to object
      when Labimotion::FieldType::DRAG_SAMPLE
        val = field.fetch('value', nil)
        if val.present?
          instance = Sample.find_by(id: val['el_id'])
          field_obj[:value] = val['el_label']
          field_obj[:has_structure] = true
          obj_os = Entities::SampleReportEntity.new(
            instance,
            current_user: @current_user,
            detail_levels: ElementDetailLevelCalculator.new(user: @current_user, element: instance).detail_levels,
          ).serializable_hash
          obj_final = OpenStruct.new(obj_os)
          field_obj[:structure] = Reporter::Docx::DiagramSample.new(obj: obj_final, format: 'png').generate
        end
      when Labimotion::FieldType::SYS_REACTION
        val = field.fetch('value', nil)
        if val.present?
          instance = Reaction.find_by(id: val['el_id'])
          field_obj[:value] = val['el_label']
          field_obj[:has_structure] = true
          obj_os = Entities::ReactionReportEntity.new(
            instance,
            current_user: @current_user,
            detail_levels: ElementDetailLevelCalculator.new(user: @current_user, element: instance).detail_levels,
          ).serializable_hash
          obj_final = OpenStruct.new(obj_os)
          field_obj[:structure] = Reporter::Docx::DiagramReaction.new(obj: obj_final, format: 'png').generate
        end
      when Labimotion::FieldType::DRAG_MOLECULE
        val = field.fetch('value', nil)
        if val.present?
          obj = Molecule.find_by(id: val['el_id'])
          field_obj[:value] = val['el_label']
        end
      when Labimotion::FieldType::SELECT
        field_obj[:value] = @options.fetch(field['option_layers'], nil)&.fetch('options', nil)&.find { |ss| ss['key'] == field['value'] }&.fetch('label', nil) || field['value']
      when Labimotion::FieldType::UPLOAD
        files = field.fetch('value', nil)&.fetch('files', [])
        val = files&.map { |file| "#{file['filename']} #{file['label']}" }&.join('\n')
        field_obj[:value] = val
      when Labimotion::FieldType::TABLE
        field_obj[:is_table] = false
        field_obj[:not_table] = true
        field_obj[:value] = build_table_wordml(field)
      when Labimotion::FieldType::DATETIME_RANGE
        field_obj[:is_table] = false
        field_obj[:not_table] = true
        field_obj[:value] = build_datetime_range_wordml(field)
      when Labimotion::FieldType::INPUT_GROUP
        val = []
        field.fetch('sub_fields', [])&.each do |sub_field|
          if sub_field['type'] == Labimotion::FieldType::SYSTEM_DEFINED
            val.push("#{sub_field['value']} #{sub_field['value_system']}")
          else
            val.push(sub_field['value'])
          end
        end
        field_obj[:value] = val.join(' ')
      when Labimotion::FieldType::WF_NEXT
        if field['value'].present? && field['wf_options'].present?
          field_obj[:value] = field['wf_options'].find { |ss| ss['key'] == field['value'] }&.fetch('label', nil)&.split('(')&.first&.strip
        end
      when Labimotion::FieldType::SYSTEM_DEFINED
        _field = field
        unit = Labimotion::Units::FIELDS.find { |o| o[:field] == _field['option_layers'] }&.fetch(:units, []).find { |u| u[:key] == _field['value_system'] }&.fetch(:label, '')
        val = _field['value'].to_s + ' ' + unit
        val = Sablon.content(:html, "<div>" + val + "</div>") if val.include? '<'
        field_obj[:value] = val
      when Labimotion::FieldType::TEXT_FORMULA
        field.fetch('text_sub_fields', []).each do |sub_field|
          va = @properties['layers'][sub_field.fetch('layer','')]['fields'].find { |f| f['field'] == sub_field.fetch('field','') }&.fetch('value',nil)
          field_obj[:value] = (field_obj[:value] || '') + va.to_s + sub_field.fetch('separator','') if va.present?
        end
        # field_obj[:value] = (field['value'] && field['value']['el_label']) || ''
        # field_obj[:obj] = field['value']  ### change to object
      else
        field_obj[:value] = field['value']
      end
      field_obj
    rescue StandardError => e
      Labimotion.log_exception(e)
    end

    def build_table_field(sub_val, sub_field)
      return '' if sub_field.fetch('id', nil).nil? || sub_val[sub_field['id']].nil?

      case sub_field['type']
      when Labimotion::FieldType::DRAG_SAMPLE
        val = sub_val[sub_field['id']]['value'] || {}
        label = val['el_label'].present? ? "Short Label: [#{val['el_label']}] \n" : ''
        name = val['el_name'].present? ? "Name: [#{val['el_name']}] \n" : ''
        ext = val['el_external_label'].present? ? "Ext. Label: [#{val['el_external_label']}] \n" : ''
        mass = val['el_molecular_weight'].present? ? "Mass: [#{val['el_molecular_weight']}] \n" : ''
        url = val['el_id'].present? ? "#{sample_url}/#{val['el_id']}" : ''
        "#{label}#{name}#{ext}#{mass}#{url}"
      when Labimotion::FieldType::DRAG_MOLECULE
        val = sub_val[sub_field['id']]['value'] || {}
        smile = val['el_smiles'].present? ? "SMILES: [#{val['el_smiles']}] \n" : ''
        inchikey = val['el_inchikey'].present? ? "InChiKey:[#{val['el_inchikey']}] \n" : ''
        iupac = val['el_iupac'].present? ? "IUPAC:[#{val['el_iupac']}] \n" : ''
        mass = val['el_molecular_weight'].present? ? "MASS: [#{val['el_molecular_weight']}] \n" : ''
        "#{smile}#{inchikey}#{iupac}#{mass}"
      when Labimotion::FieldType::SELECT
        sub_val[sub_field['id']]['value']
      when Labimotion::FieldType::SYSTEM_DEFINED
        unit = Labimotion::Units::FIELDS.find { |o| o[:field] == sub_field['option_layers'] }&.fetch(:units, [])&.find { |u| u[:key] == sub_val[sub_field['id']]['value_system'] }&.fetch(:label, '')
        val = sub_val[sub_field['id']]['value'].to_s + ' ' + unit
        val = Sablon.content(:html, "<div>" + val + "</div>") if val.include? '<'
        val
      else
        sub_val[sub_field['id']]
      end
    end

    TABLE_BLANK_WORDML = '<w:p/>'
    TABLE_BORDER = '<w:tblBorders>' \
                   '<w:top w:val="single" w:sz="4" w:color="auto"/>' \
                   '<w:left w:val="single" w:sz="4" w:color="auto"/>' \
                   '<w:bottom w:val="single" w:sz="4" w:color="auto"/>' \
                   '<w:right w:val="single" w:sz="4" w:color="auto"/>' \
                   '<w:insideH w:val="single" w:sz="4" w:color="auto"/>' \
                   '<w:insideV w:val="single" w:sz="4" w:color="auto"/>' \
                   '</w:tblBorders>'

    def build_table_wordml(field)
      sub_fields = field.fetch('sub_fields', [])
      return Sablon.content(:word_ml, TABLE_BLANK_WORDML) if sub_fields.empty?

      width = (9000.0 / sub_fields.length).round
      font_size = sub_fields.length > 6 ? 16 : 20
      grid = sub_fields.map { %(<w:gridCol w:w="#{width}"/>) }.join
      header = build_table_header_row(sub_fields, width, font_size)
      rows = build_table_body_rows(field.fetch('sub_values', []), sub_fields, width, font_size)
      tbl = '<w:tbl><w:tblPr><w:tblW w:w="5000" w:type="pct"/>' \
            "#{TABLE_BORDER}</w:tblPr><w:tblGrid>#{grid}</w:tblGrid>" \
            "#{header}#{rows}</w:tbl>"
      Sablon.content(:word_ml, tbl)
    rescue StandardError => e
      Labimotion.log_exception(e)
      Sablon.content(:word_ml, TABLE_BLANK_WORDML)
    end

    DATETIME_RANGE_HEADERS = ['Start', 'Stop', 'Duration (calc)', 'Duration'].freeze
    DATETIME_RANGE_PRECISE_LABELS = %w[year month day hour minute second].freeze
    DURATION_UNIT_LABELS = {
      'd' => 'day',
      'h' => 'hour',
      'min' => 'minute',
      's' => 'second'
    }.freeze

    def build_datetime_range_wordml(field)
      sub_fields = field.fetch('sub_fields', []) || []
      by_col = sub_fields.each_with_object({}) { |sf, h| h[sf['col_name']] = sf if sf.is_a?(Hash) }
      values = datetime_range_values(by_col)
      datetime_range_wordml_table(values)
    rescue StandardError => e
      Labimotion.log_exception(e)
      Sablon.content(:word_ml, TABLE_BLANK_WORDML)
    end

    def datetime_range_values(by_col)
      time_start = by_col['timeStart']&.dig('value').to_s
      time_stop = by_col['timeStop']&.dig('value').to_s
      [
        time_start,
        time_stop,
        format_duration_calc(by_col['durationCalc'], time_start, time_stop),
        format_duration_value(by_col['duration'])
      ]
    end

    def datetime_range_wordml_table(values)
      width = (9000.0 / DATETIME_RANGE_HEADERS.length).round
      font_size = 20
      grid = DATETIME_RANGE_HEADERS.map { %(<w:gridCol w:w="#{width}"/>) }.join
      header_cells = DATETIME_RANGE_HEADERS.map { |h| build_wordml_cell(h, width, font_size, true) }.join
      body_cells = values.map { |v| build_wordml_cell(v, width, font_size, false) }.join
      tbl = '<w:tbl><w:tblPr><w:tblW w:w="5000" w:type="pct"/>' \
            "#{TABLE_BORDER}</w:tblPr><w:tblGrid>#{grid}</w:tblGrid>" \
            "<w:tr>#{header_cells}</w:tr><w:tr>#{body_cells}</w:tr></w:tbl>"
      Sablon.content(:word_ml, tbl)
    end

    def format_duration_value(duration_sf)
      val = duration_sf&.dig('value')
      return '' if val.nil? || val.to_s.empty?

      "#{val} #{duration_unit_label(duration_sf['value_system'], val)}".strip
    end

    def duration_unit_label(value_system, value)
      base = DURATION_UNIT_LABELS[value_system.to_s]
      return value_system.to_s if base.nil?

      pluralize_unit?(value) ? "#{base}s" : base
    end

    def pluralize_unit?(value)
      numeric = Float(value.to_s)
      (numeric - 1.0).abs > Float::EPSILON
    rescue ArgumentError, TypeError
      true
    end

    def format_duration_calc(_duration_calc_sf, time_start, time_stop)
      compute_duration_calc(time_start, time_stop)
    end

    def compute_duration_calc(time_start, time_stop)
      start_t = parse_datetime_range_value(time_start)
      stop_t = parse_datetime_range_value(time_stop)
      return '' unless start_t && stop_t && stop_t > start_t

      precise_diff_humanize(start_t, stop_t)
    end

    def parse_datetime_range_value(str)
      cleaned = str.to_s.strip
      return nil if cleaned.empty?

      parts = Date._parse(cleaned)
      return nil unless datetime_range_parts_complete?(parts)

      build_utc_from_parts(parts)
    rescue ArgumentError
      nil
    end

    def datetime_range_parts_complete?(parts)
      %i[year mon mday].all? { |k| parts[k] }
    end

    def build_utc_from_parts(parts)
      Time.utc(parts[:year], parts[:mon], parts[:mday],
               parts[:hour] || 0, parts[:min] || 0, parts[:sec] || 0)
    end

    def precise_diff_humanize(start_t, stop_t)
      components = precise_diff_components(start_t, stop_t)
      parts = components.zip(DATETIME_RANGE_PRECISE_LABELS).reject { |n, _| n <= 0 }
      return '0 seconds' if parts.empty?

      parts.map { |n, label| format_precise_part(n, label) }.join(' ')
    end

    def format_precise_part(count, label)
      suffix = count == 1 ? '' : 's'
      "#{count} #{label}#{suffix}"
    end

    def precise_diff_components(start_t, stop_t)
      y, m, d, h, mi, s = precise_diff_raw(start_t, stop_t)
      mi, s = borrow_unit(mi, s, 60)
      h, mi = borrow_unit(h, mi, 60)
      d, h = borrow_unit(d, h, 24)
      if d.negative?
        m -= 1
        d += (Date.new(stop_t.year, stop_t.month, 1) - 1).day
      end
      y, m = borrow_unit(y, m, 12)
      [y, m, d, h, mi, s]
    end

    def borrow_unit(higher, lower, base)
      return [higher, lower] unless lower.negative?

      [higher - 1, lower + base]
    end

    def precise_diff_raw(start_t, stop_t)
      [
        stop_t.year - start_t.year,
        stop_t.month - start_t.month,
        stop_t.day - start_t.day,
        stop_t.hour - start_t.hour,
        stop_t.min - start_t.min,
        stop_t.sec - start_t.sec
      ]
    end

    def build_table_header_row(sub_fields, width, font_size)
      cells = sub_fields.map { |sf| build_wordml_cell(sf['col_name'].to_s, width, font_size, true) }.join
      "<w:tr>#{cells}</w:tr>"
    end

    def build_table_body_rows(sub_values, sub_fields, width, font_size)
      sub_values.map do |sv|
        cells = sub_fields.map { |sf| build_wordml_cell(table_cell_text(sv, sf), width, font_size, false) }.join
        "<w:tr>#{cells}</w:tr>"
      end.join
    end

    def build_wordml_cell(text, width, font_size, bold)
      bold_xml = bold ? '<w:b/>' : ''
      rpr = "<w:rPr>#{bold_xml}<w:sz w:val=\"#{font_size}\"/></w:rPr>"
      lines = text.to_s.split(/\r?\n/)
      lines = [''] if lines.empty?
      paragraphs = lines.map do |line|
        "<w:p><w:r>#{rpr}<w:t xml:space=\"preserve\">#{xml_escape(line)}</w:t></w:r></w:p>"
      end.join
      "<w:tc><w:tcPr><w:tcW w:w=\"#{width}\" w:type=\"dxa\"/></w:tcPr>#{paragraphs}</w:tc>"
    end

    def xml_escape(str)
      str.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
    end

    TABLE_CELL_TEXT_RENDERERS = {
      Labimotion::FieldType::DRAG_SAMPLE => ->(_sf, c, ctx) { ctx.table_cell_sample_text(c['value'] || {}) },
      Labimotion::FieldType::DRAG_MOLECULE => ->(_sf, c, ctx) { ctx.table_cell_molecule_text(c['value'] || {}) },
      Labimotion::FieldType::SELECT => ->(_sf, c, _ctx) { c['value'].to_s },
      Labimotion::FieldType::SYSTEM_DEFINED => ->(sf, c, ctx) { ctx.table_cell_sysdef_text(sf, c) }
    }.freeze

    def table_cell_text(sub_val, sub_field)
      return '' if sub_field.fetch('id', nil).nil? || sub_val[sub_field['id']].nil?

      cell = sub_val[sub_field['id']]
      renderer = TABLE_CELL_TEXT_RENDERERS[sub_field['type']]
      return renderer.call(sub_field, cell, self) if renderer

      raw = cell.is_a?(Hash) ? cell['value'] : cell
      raw.to_s
    end

    def table_cell_sample_text(val)
      parts = []
      parts << "Short Label: [#{val['el_label']}]" if val['el_label'].present?
      parts << "Name: [#{val['el_name']}]" if val['el_name'].present?
      parts << "Ext. Label: [#{val['el_external_label']}]" if val['el_external_label'].present?
      parts << "Mass: [#{val['el_molecular_weight']}]" if val['el_molecular_weight'].present?
      parts << "#{sample_url}/#{val['el_id']}" if val['el_id'].present?
      parts.join("\n")
    end

    def table_cell_molecule_text(val)
      parts = []
      parts << "SMILES: [#{val['el_smiles']}]" if val['el_smiles'].present?
      parts << "InChiKey: [#{val['el_inchikey']}]" if val['el_inchikey'].present?
      parts << "IUPAC: [#{val['el_iupac']}]" if val['el_iupac'].present?
      parts << "MASS: [#{val['el_molecular_weight']}]" if val['el_molecular_weight'].present?
      parts.join("\n")
    end

    def table_cell_sysdef_text(sub_field, cell)
      fdef = Labimotion::Units::FIELDS.find { |o| o[:field] == sub_field['option_layers'] }
      unit = fdef&.fetch(:units, [])&.find { |u| u[:key] == cell['value_system'] }&.fetch(:label, '')
      "#{cell['value']} #{unit}".strip
    end

    def build_fields(layer)
      fields = layer[Labimotion::Prop::FIELDS] || []
      field_objs = []
      fields.each do |field|
        next if field['type'] == 'dummy'

        field_obj = build_field(layer, field)
        field_objs.push(field_obj)
      end
      field_objs
    rescue StandardError => e
      Labimotion.log_exception(e)
    end

    def to_docx
      # location = Rails.root.join('lib', 'template', 'Labimotion.docx')
      location = Rails.root.join('lib', 'template', 'Labimotion_lines.docx')
      # location = Rails.root.join('lib', 'template', 'Labimotion_img.docx')
      File.exist?(location)
      template = Sablon.template(location)
      layers = build_layers
      context = {
        label: @element_klass.label,
        desc: @element_klass.desc,
        name: @name,
        parent_klass: @parent.present? ? "#{@parent&.class&.name&.split('::')&.last}: " : '',
        short_label: @short_label,
        date: Time.now.strftime('%d/%m/%Y'),
        author: @current_user.name,
        layers: layers
      }
      tempfile = Tempfile.new('labimotion.docx')
      template.render_to_file File.expand_path(tempfile), context
      content = File.read(tempfile)
      content
    rescue StandardError => e
      Labimotion.log_exception(e)
    ensure
      # Close and delete the temporary file
      tempfile&.close
      tempfile&.unlink
    end


    def res_name
      "#{@element_name}_#{Time.now.strftime('%Y%m%d%H%M')}.docx"
    rescue StandardError => e
      Labimotion.log_exception(e)
    end

    def build_field_html(layer, field, cols)
      case field['type']
      when Labimotion::FieldType::DRAG_SAMPLE, Labimotion::FieldType::DRAG_ELEMENT, Labimotion::FieldType::DRAG_MOLECULE
        val = (field['value'] && field['value']['el_label']) || ''
      when Labimotion::FieldType::UPLOAD
        val = (field['value'] && field['value']['files'] && field['value']['files'].first && field['value']['files'].first['filename'] ) || ''
      else
        val = field['value']
      end
      htd = field['hasOwnRow'] == true ? "<td colspan=#{cols}>" : '<td>'
      "#{htd}<b>#{field['label']}: </b><br />#{val}</td>"
    rescue StandardError => e
      Labimotion.log_exception(e)
    end

    def build_fields_html(layer)
      fields = layer[Labimotion::Prop::FIELDS] || []
      field_objs = []
      cols = layer['cols'] || 0
      field_objs.push('<table style="width: 4000dxa"><tr>')
      fields.each do |field|
        if cols&.zero? || field['hasOwnRow'] == true
          field_objs.push('</tr><tr>')
          cols = layer['cols']
        end
        field_obj = build_field_html(layer, field, layer['cols'])
        field_objs.push(field_obj)
        cols -= 1
        cols = 0 if field['hasOwnRow'] == true
      end
      field_objs.push('</tr></table>')
      field_objs&.join("")&.gsub('<tr></tr>', '')
    rescue StandardError => e
      Labimotion.log_exception(e)
    end


    def build_layers_html
      layer_html = []
      first_line = true
      @properties[Labimotion::Prop::LAYERS]&.keys&.each do |key|
        layer_html.push('</tr></table>') if first_line == false
        layer = @properties[Labimotion::Prop::LAYERS][key] || {}
        fields = layer[Labimotion::Prop::FIELDS] || []
        layer_html.push("<h2><b>Layer:#{layer['label']}</b></h2>")
        layer_html.push('<table><tr>')
        cols = layer['cols']
        fields.each do |field|
          if (cols === 0)
            layer_html.push('</tr><tr>')
          end

          val = field['value'].is_a?(Hash) ? field['value']['el_label'] : field['value']
          layer_html.push("<td>#{field['label']}: <br />#{val}</td>")
          cols -= 1
        end
        first_line = false
      end
      layer_html.push('</tr></table>')
      layer_html.join('')
    rescue StandardError => e
      Labimotion.log_exception(e)
    end

    def html_labimotion
      layers_html = build_layers_html
      html_body = <<-HTML.strip
      #{layers_html}
      HTML
      html_body
    rescue StandardError => e
      Labimotion.log_exception(e)
    end
  end
end
