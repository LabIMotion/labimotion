# frozen_string_literal: true
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
        field_obj[:is_table] = true
        field_obj[:not_table] = false
        tbl = []
        ## tbl_idx = []
        header = {}
        sub_fields = field.fetch('sub_fields', [])
        sub_fields.each_with_index do |sub_field, idx|
          header["col#{idx}"] = sub_field['col_name']
        end
        tbl.push(header)
        field.fetch('sub_values', []).each do |sub_val|
          data = {}
          sub_fields.each_with_index do |sub_field, idx|
            data["col#{idx}"] = build_table_field(sub_val, sub_field)
          end
          tbl.push(data)
        end
        field_obj[:data] = tbl
        # field_obj[:value] = 'this is a table'
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
        "#{label}#{name}#{ext}#{mass}"
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
        unit = Labimotion::Units::FIELDS.find { |o| o[:field] == sub_field['option_layers'] }&.fetch(:units, [])&.find { |u| u[:key] == sub_field['value_system'] }&.fetch(:label, '')
        val = sub_val[sub_field['id']]['value'].to_s + ' ' + unit
        val = Sablon.content(:html, "<div>" + val + "</div>") if val.include? '<'
        val
      else
        sub_val[sub_field['id']]
      end
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
