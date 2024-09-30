require 'labimotion/entities/application_entity'

module Labimotion
  class PropertiesEntity < Labimotion::ApplicationEntity
    def properties
      process_layers do |key, layer|
        process_fields(key, layer)
      end
      object.properties
    end

    private

    def process_layers
      (object&.properties.is_a?(Hash) && (object.properties[Labimotion::Prop::LAYERS]&.keys || [])).each do |key|
        yield(key, object.properties[Labimotion::Prop::LAYERS][key])
      end
    end

    def process_fields(key, layer)
      process_sample_and_molecule_fields(key, layer)
      process_reaction_fields(key, layer)
      process_table_fields(key, layer)
      # process_voc_fields(key, layer)
    end

    def process_sample_and_molecule_fields(key, layer)
      select_fields(layer,
                    [Labimotion::FieldType::DRAG_SAMPLE, Labimotion::FieldType::DRAG_MOLECULE]).each do |field, idx|
        update_sample_or_molecule_field(key, field, idx)
      end
    end

    def process_reaction_fields(key, layer)
      select_fields(layer, [Labimotion::FieldType::SYS_REACTION]).each do |field, idx|
        update_reaction_field(key, field, idx)
      end
    end

    def process_table_fields(key, layer)
      select_fields(layer, [Labimotion::FieldType::TABLE]).each do |field, idx|
        update_table_field(key, field, idx)
      end
    end

    def process_voc_fields(key, layer)
      select_fields(layer, nil, true).each do |field, idx|
        update_voc_field(key, field, idx)
      end
    end

    def select_fields(layer, types = nil, is_voc = false)
      fields = layer[Labimotion::Prop::FIELDS]
      fields = fields.select { |f| types.include?(f['type']) } if types
      fields = fields.select { |f| f['is_voc'] == true } if is_voc
      fields.map { |f| [f, layer[Labimotion::Prop::FIELDS].index(f)] }
    end

    def update_sample_or_molecule_field(key, field, idx)
      sid = field.dig('value', 'el_id')
      return unless sid.present?

      el = field['type'] == Labimotion::FieldType::DRAG_SAMPLE ? Sample.find_by(id: sid) : Molecule.find_by(id: sid)
      return unless el.present? && object.properties.dig(Labimotion::Prop::LAYERS, key, Labimotion::Prop::FIELDS, idx,
                                                         'value').present?

      label = field['type'] == Labimotion::FieldType::DRAG_SAMPLE ? el&.short_label : el.iupac_name
      update_field_value(key, idx, {
                           'el_label' => label,
                           'el_tip' => label,
                           'el_svg' => if field['type'] == Labimotion::FieldType::DRAG_SAMPLE
                                         el&.get_svg_path
                                       else
                                         File.join('/images',
                                                   'molecules', el&.molecule_svg_file || 'nosvg')
                                       end
                         })
    end

    def update_reaction_field(key, field, idx)
      sid = field.dig('value', 'el_id')
      return unless sid.present?

      el = Reaction.find_by(id: sid)
      if el.blank?
        update_field_value(key, idx, { 'el_tip' => 'ERROR', 'el_svg' => '' })
        return
      end

      return unless object.properties.dig(Labimotion::Prop::LAYERS, key, Labimotion::Prop::FIELDS, idx,
                                          'value').present?

      update_field_value(key, idx, {
                           'el_label' => el.short_label,
                           'el_tip' => el.short_label,
                           'el_svg' => el.reaction_svg_file
                         })
    end

    def update_table_field(key, field, idx)
      return unless field['sub_values'].present? && field[Labimotion::Prop::SUBFIELDS].present?

      field_table_molecules = field[Labimotion::Prop::SUBFIELDS].select do |ss|
        ss['type'] == Labimotion::FieldType::DRAG_MOLECULE
      end
      if field_table_molecules.present?
        object.properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx] =
          set_table(field, field_table_molecules, Labimotion::Prop::MOLECULE)
      end

      field_table_samples = field[Labimotion::Prop::SUBFIELDS].select do |ss|
        ss['type'] == Labimotion::FieldType::DRAG_SAMPLE
      end
      return unless field_table_samples.present?

      object.properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx] =
        set_table(field, field_table_samples, Labimotion::Prop::SAMPLE)
    end

    def update_voc_field(key, field, idx)
      root_element = get_root_element
      case field['source']
      when Labimotion::Prop::ELEMENT
        update_element_voc_field(key, field, idx, root_element)
      when Labimotion::Prop::SEGMENT
        update_segment_voc_field(key, field, idx, root_element)
      when Labimotion::Prop::DATASET
        update_dataset_voc_field(key, field, idx, root_element)
      end
    end

    def get_root_element
      case object.class.name
      when Labimotion::Prop::L_ELEMENT
        object
      when Labimotion::Prop::L_SEGMENT
        object&.element
      when Labimotion::Prop::L_DATASET
        object&.element&.root_element
      end
    end

    def update_element_voc_field(key, field, idx, root_element)
      return unless field['identifier'] == 'element.name'

      update_field_value(key, idx, root_element&.name)
    end

    def update_segment_voc_field(key, field, idx, root_element)
      segs = root_element&.segments&.select { |ss| field['source_id'] == ss.segment_klass&.identifier }
      return if segs.empty? || field['layer_id'].blank? || field['field_id'].blank?

      seg = segs&.first
      seg_fields = seg.properties.dig(Labimotion::Prop::LAYERS, field['layer_id'],
                                      Labimotion::Prop::FIELDS).select do |ff|
        ff['field'] == field['field_id']
      end
      seg_field = seg_fields&.first
      update_field_value(key, idx, seg_field['value'])
    end

    def update_dataset_voc_field(key, field, idx, root_element)
      dk = DatasetKlass.find_by(identifier: field['source_id'])
      dk['ols_term_id']
      anas = root_element.analyses.select do |ana|
        ana.extended_metadata['kind'].split('|')&.first&.strip == dk['ols_term_id']
      end
      anas.each do |ana|
        ana.children.each do |cds|
          next unless cds.dataset.present?

          ds_prop = cds.dataset.properties
          ds_fields = ds_prop.dig(Labimotion::Prop::LAYERS, field['layer_id'], Labimotion::Prop::FIELDS).select do |ff|
            ff['field'] == field['field_id']
          end
          ds_field = ds_fields&.first
          if object.properties[Labimotion::Prop::LAYERS][key].present? && ds_field['value'].present?
            update_field_value(key, idx, ds_field['value'])
          end
        end
      end
    end

    def update_field_value(key, idx, value, act = 'merge')
      field_path = object.properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]
      original_value = field_path['value']

      field_path['value'] = merge_values(original_value, value, act)
    end

    def merge_by_type(original_value, new_value)
      if original_value.is_a?(Hash)
        merge_hash_values(original_value, new_value)
      # elsif original_value.is_a?(Array)
      #   merge_array_values(original_value, new_value)
      else
        new_value
      end
    end

    def merge_values(original_value, new_value, act)
      return new_value if act == 'overwrite'
      return new_value if original_value.blank?
      return original_value if new_value.blank?

      merge_by_type(original_value, new_value)
    end

    def set_table(field, field_table_objs, obj)
      col_ids = field_table_objs.map { |x| x.values[0] }
      col_ids.each do |col_id|
        field['sub_values'].each do |sub_value|
          unless sub_value[col_id].present? && sub_value[col_id]['value'].present? && sub_value[col_id]['value']['el_id'].present?
            next
          end

          find_obj = obj.constantize.find_by(id: sub_value[col_id]['value']['el_id'])
          next if find_obj.blank?

          case obj
          when Labimotion::Prop::MOLECULE
            update_molecule_sub_value(sub_value, col_id, find_obj)
          when Labimotion::Prop::SAMPLE
            update_sample_sub_value(sub_value, col_id, find_obj)
          end
        end
      end
      field
    end

    def update_molecule_sub_value(sub_value, col_id, find_obj)
      sub_value[col_id]['value'].merge!({
                                          'el_svg' => File.join('/images', 'molecules', find_obj.molecule_svg_file),
                                          'el_inchikey' => find_obj.inchikey,
                                          'el_smiles' => find_obj.cano_smiles,
                                          'el_iupac' => find_obj.iupac_name,
                                          'el_molecular_weight' => find_obj.molecular_weight
                                        })
    end

    def update_sample_sub_value(sub_value, col_id, find_obj)
      sub_value[col_id]['value'].merge!({
                                          'el_svg' => find_obj.get_svg_path,
                                          'el_label' => find_obj.short_label,
                                          'el_short_label' => find_obj.short_label,
                                          'el_name' => find_obj.name,
                                          'el_external_label' => find_obj.external_label,
                                          'el_molecular_weight' => find_obj.decoupled ? find_obj.molecular_mass : find_obj.molecule.molecular_weight
                                        })
    end

    def merge_hash_values(original, new_value)
      return original unless new_value.is_a?(Hash)

      original.merge(new_value)
    end

    def merge_array_values(original, new_value)
      return original unless new_value.respond_to?(:to_a)

      (original + new_value.to_a).uniq
    end
  end
end
