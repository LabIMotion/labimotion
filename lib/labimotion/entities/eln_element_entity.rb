# frozen_string_literal: true
#
require 'labimotion/entities/application_entity'
module Labimotion
  ## ElementEntity
  class ElnElementEntity < ApplicationEntity
    with_options(anonymize_below: 0) do
      expose! :created_by
      expose! :id
      expose! :is_restricted
      expose! :klass_uuid
      expose! :name
      expose! :properties
      expose! :properties_release
      expose! :short_label
      expose! :type
      expose! :uuid
    end

    expose(
      :can_copy, unless: ->(_instance, _options) { displayed_in_list? }
    )

    private

    def properties
      (object.properties['layers']&.keys || []).each do |key|
        # layer = object.properties[key]
        field_sample_molecules = object.properties['layers'][key]['fields'].select do |ss|
          ss['type'] == 'drag_sample' || ss['type'] == 'drag_molecule'
        end
        field_sample_molecules.each do |field|
          idx = object.properties['layers'][key]['fields'].index(field)
          sid = field.dig('value', 'el_id')
          next unless sid.present?

          el = field['type'] == 'drag_sample' ? Sample.find_by(id: sid) : Molecule.find_by(id: sid)
          next unless el.present?
          next unless object.properties.dig('layers', key, 'fields', idx, 'value').present?

          if field['type'] == 'drag_sample'
            object.properties['layers'][key]['fields'][idx]['value']['el_label'] =
              el.short_label
          end
          if field['type'] == 'drag_sample'
            object.properties['layers'][key]['fields'][idx]['value']['el_tip'] =
              el.short_label
          end
          object.properties['layers'][key]['fields'][idx]['value']['el_svg'] =
            field['type'] == 'drag_sample' ? el.get_svg_path : File.join('/images', 'molecules', el.molecule_svg_file)
        end

        field_tables = object.properties['layers'][key]['fields'].select { |ss| ss['type'] == 'table' }
        field_tables.each do |field|
          idx = object.properties['layers'][key]['fields'].index(field)
          next unless field['sub_values'].present? && field['sub_fields'].present?

          field_table_molecules = field['sub_fields'].select { |ss| ss['type'] == 'drag_molecule' }
          if field_table_molecules.present?
            object.properties['layers'][key]['fields'][idx] =
              set_table(field, field_table_molecules, 'Molecule')
          end

          field_table_samples = field['sub_fields'].select { |ss| ss['type'] == 'drag_sample' }
          if field_table_samples.present?
            object.properties['layers'][key]['fields'][idx] =
              set_table(field, field_table_samples, 'Sample')
          end
        end
      end
      object.properties
    end

    def type
      object.element_klass.name
    end

    def set_table(field, field_table_objs, obj)
      col_ids = field_table_objs.map { |x| x.values[0] }
      col_ids.each do |col_id|
        field['sub_values'].each do |sub_value|
          unless sub_value[col_id].present? && sub_value[col_id]['value'].present? && sub_value[col_id]['value']['el_id'].present?
            next
          end

          find_obj = obj.constantize.find_by(id: sub_value[col_id]['value']['el_id'])
          next unless find_obj.present?

          case obj
          when 'Molecule'
            sub_value[col_id]['value']['el_svg'] = File.join('/images', 'molecules', find_obj.molecule_svg_file)
            sub_value[col_id]['value']['el_inchikey'] = find_obj.inchikey
            sub_value[col_id]['value']['el_smiles'] = find_obj.cano_smiles
            sub_value[col_id]['value']['el_iupac'] = find_obj.iupac_name
            sub_value[col_id]['value']['el_molecular_weight'] = find_obj.molecular_weight
          when 'Sample'
            sub_value[col_id]['value']['el_svg'] = find_obj.get_svg_path
            sub_value[col_id]['value']['el_label'] = find_obj.short_label
            sub_value[col_id]['value']['el_short_label'] = find_obj.short_label
            sub_value[col_id]['value']['el_name'] = find_obj.name
            sub_value[col_id]['value']['el_external_label'] = find_obj.external_label
            sub_value[col_id]['value']['el_molecular_weight'] =
              find_obj.decoupled ? find_obj.molecular_mass : find_obj.molecule.molecular_weight
          end
        end
      end
      field
    end
  end
end
