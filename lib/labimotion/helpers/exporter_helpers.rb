# frozen_string_literal: true

module Labimotion
  # ExporterHelpers provides utility methods for formatting and processing export data
  module ExporterHelpers
    # Constants
    CONST_UNNAMED = '(Unnamed)'

    # Normalize column name, returns CONST_UNNAMED for blank values
    def normalize_column_name(col_name)
      return CONST_UNNAMED if col_name.nil? || col_name.to_s.strip.empty?

      col_name
    end

    # Check if field type should be expanded (DRAG_SAMPLE or DRAG_MOLECULE)
    def expandable_field?(field_type)
      [Labimotion::FieldType::DRAG_SAMPLE, Labimotion::FieldType::DRAG_MOLECULE].include?(field_type)
    end

    # Generate sanitized filename for export
    def generate_filename(element_name, segment_name, layer_name, field_name)
      timestamp = Time.zone.now.strftime('%Y%m%d_%H%M%S')
      parts = [element_name]
      parts << segment_name unless segment_name.empty?
      parts.push(layer_name, field_name, timestamp)
      parts.join('_').gsub(/\s+/, '_').gsub(/[()]/, '(' => '[', ')' => ']')
    end

    # Format table cell value based on field type
    def format_table_cell(sub_val, sub_field)
      return '' if sub_field.fetch('id', nil).nil? || sub_val[sub_field['id']].nil?

      case sub_field['type']
      when Labimotion::FieldType::DRAG_SAMPLE, Labimotion::FieldType::DRAG_MOLECULE
        format_drag_field_cell(sub_val, sub_field)
      when Labimotion::FieldType::SELECT
        format_select_cell(sub_val, sub_field)
      when Labimotion::FieldType::SYSTEM_DEFINED
        format_system_defined_cell(sub_val, sub_field)
      else
        format_default_cell(sub_val, sub_field)
      end
    rescue StandardError => e
      Labimotion.log_exception(e)
      ''
    end

    # Format expanded cell for DRAG_SAMPLE or DRAG_MOLECULE with sub-headers
    def format_expanded_cell(sub_val, exp_field)
      field_id = exp_field['id']
      sub_header = exp_field['sub_header']

      return '' if field_id.nil? || sub_val[field_id].nil?

      val = sub_val[field_id]['value'] || {}
      return '' if val.blank? || !val.is_a?(Hash)

      property_key = map_sub_header_to_property(sub_header)
      val[property_key].to_s
    rescue StandardError => e
      Labimotion.log_exception(e)
      ''
    end

    # Map sub-header to property key
    def map_sub_header_to_property(sub_header)
      property_map = {
        'name' => 'el_name',
        'label' => 'el_label',
        'short_label' => 'el_short_label',
        'external_label' => 'el_external_label',
        'molecular_weight' => 'el_molecular_weight',
        'smiles' => 'el_smiles',
        'inchikey' => 'el_inchikey',
        'iupac' => 'el_iupac',
        'sum_formula' => 'el_sum_formula',
        'decoupled' => 'el_decoupled'
      }

      property_map[sub_header] || "el_#{sub_header}"
    end

    # Format drag field cell (DRAG_SAMPLE or DRAG_MOLECULE), returns hyperlink or label
    def format_drag_field_cell(sub_val, sub_field)
      val = sub_val[sub_field['id']]['value'] || {}
      return '' if val.blank?

      svg_url = val['el_svg'].to_s
      if svg_url.present?
        full_url = URI.join(Rails.application.config.root_url, svg_url).to_s
        { hyperlink: full_url, text: '[image link]' }
      else
        val['el_label'].to_s
      end
    end

    # Format select cell
    def format_select_cell(sub_val, sub_field)
      sub_val[sub_field['id']]['value'].to_s
    end

    # Format system-defined cell with unit
    def format_system_defined_cell(sub_val, sub_field)
      value = sub_val[sub_field['id']]['value'].to_s
      unit = find_unit_label(sub_val, sub_field)

      unit.present? ? "#{value} #{unit}" : value
    end

    # Find unit label for system-defined field
    def find_unit_label(sub_val, sub_field)
      value_system = extract_value_system(sub_val, sub_field)
      find_unit_by_key(sub_field['option_layers'], value_system)
    end

    # Extract value_system from sub_val or sub_field
    def extract_value_system(sub_val, sub_field)
      field_data = sub_val[sub_field['id']]
      field_data.is_a?(Hash) ? field_data['value_system'] : sub_field['value_system']
    end

    # Find unit label by field and key
    def find_unit_by_key(option_layers, value_system)
      field_config = Labimotion::Units::FIELDS.find { |o| o[:field] == option_layers }
      return '' unless field_config

      units = field_config.fetch(:units, [])
      unit = units.find { |u| u[:key] == value_system }
      unit ? unit.fetch(:label, '') : ''
    end

    # Format default cell
    def format_default_cell(sub_val, sub_field)
      cell_data = sub_val[sub_field['id']]
      cell_data.is_a?(Hash) ? cell_data['value'].to_s : cell_data.to_s
    end
  end
end
