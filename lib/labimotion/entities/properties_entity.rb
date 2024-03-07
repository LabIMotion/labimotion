require 'labimotion/entities/application_entity'

# Entity module
module Labimotion
  class PropertiesEntity < Labimotion::ApplicationEntity

    # TODO: Refactor this method to something more readable/understandable
    def properties
      (object&.properties.is_a?(Hash) && object.properties[Labimotion::Prop::LAYERS]&.keys || []).each do |key|
        # layer = object.properties[key]
        field_sample_molecules = object.properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS].select { |ss| ss['type'] == Labimotion::FieldType::DRAG_SAMPLE || ss['type'] == Labimotion::FieldType::DRAG_MOLECULE }
        field_sample_molecules.each do |field|
          idx = object.properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS].index(field)
          sid = field.dig('value', 'el_id')
          next unless sid.present?

          el = field['type'] == Labimotion::FieldType::DRAG_SAMPLE ? Sample.find_by(id: sid) : Molecule.find_by(id: sid)
          next unless el.present?
          next unless object.properties.dig(Labimotion::Prop::LAYERS, key, Labimotion::Prop::FIELDS, idx, 'value').present?

          object.properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value']['el_label'] = el.short_label if field['type'] == Labimotion::FieldType::DRAG_SAMPLE
          object.properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value']['el_tip'] = el.short_label if field['type'] == Labimotion::FieldType::DRAG_SAMPLE
          object.properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value']['el_svg'] = field['type'] == Labimotion::FieldType::DRAG_SAMPLE ? el.get_svg_path : File.join('/images', 'molecules', el.molecule_svg_file)
        end

        field_tables = object.properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS].select { |ss| ss['type'] == Labimotion::FieldType::TABLE }
        field_tables.each do |field|
          idx = object.properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS].index(field)
          next unless field['sub_values'].present? && field[Labimotion::Prop::SUBFIELDS].present?

          field_table_molecules = field[Labimotion::Prop::SUBFIELDS].select { |ss| ss['type'] == Labimotion::FieldType::DRAG_MOLECULE }
          object.properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx] = set_table(field, field_table_molecules, Labimotion::Prop::MOLECULE) if field_table_molecules.present?

          field_table_samples = field[Labimotion::Prop::SUBFIELDS].select { |ss| ss['type'] == Labimotion::FieldType::DRAG_SAMPLE }
          object.properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx] = set_table(field, field_table_samples, Labimotion::Prop::SAMPLE) if field_table_samples.present?
        end
      end
      object.properties
    end

    def set_table(field, field_table_objs, obj)
      col_ids = field_table_objs.map { |x| x.values[0] }
      col_ids.each do |col_id|
        field['sub_values'].each do |sub_value|
          next unless sub_value[col_id].present? && sub_value[col_id]['value'].present? && sub_value[col_id]['value']['el_id'].present?

          find_obj = obj.constantize.find_by(id: sub_value[col_id]['value']['el_id'])
          next if find_obj.blank?

          case obj
          when Labimotion::Prop::MOLECULE
            sub_value[col_id]['value']['el_svg'] = File.join('/images', 'molecules', find_obj.molecule_svg_file)
            sub_value[col_id]['value']['el_inchikey'] = find_obj.inchikey
            sub_value[col_id]['value']['el_smiles'] = find_obj.cano_smiles
            sub_value[col_id]['value']['el_iupac'] = find_obj.iupac_name
            sub_value[col_id]['value']['el_molecular_weight'] = find_obj.molecular_weight
          when Labimotion::Prop::SAMPLE
            sub_value[col_id]['value']['el_svg'] = find_obj.get_svg_path
            sub_value[col_id]['value']['el_label'] = find_obj.short_label
            sub_value[col_id]['value']['el_short_label'] = find_obj.short_label
            sub_value[col_id]['value']['el_name'] = find_obj.name
            sub_value[col_id]['value']['el_external_label'] = find_obj.external_label
            sub_value[col_id]['value']['el_molecular_weight'] = find_obj.decoupled ? find_obj.molecular_mass : find_obj.molecule.molecular_weight
          end
        end
      end
      field
    end

  end
end
