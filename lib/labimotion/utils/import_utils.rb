# frozen_string_literal: true

module Labimotion
  class ImportUtils
    class << self
      private
      def upload_type(element)
        return nil if element.nil?

        case Labimotion::Utils.element_name(element.class.name)
        when Labimotion::Prop::ELEMENT
          Labimotion::Prop::ELEMENTPROPS
        when Labimotion::Prop::SEGMENT
          Labimotion::Prop::SEGMENTPROPS
        when Labimotion::Prop::DATASET
          Labimotion::Prop::DATASETPROPS
        end
      end

      def proc_assign_molecule(value, molecule)
        return {} if molecule.nil?

        value = {} if value.nil? || value.is_a?(String)
        value['el_id'] = molecule.id
        value['el_tip'] = "#{molecule.inchikey}@@#{molecule.cano_smiles}"
        value['el_label'] = molecule.iupac_name
        value['el_svg'] = File.join('/images', 'molecules', molecule.molecule_svg_file)
        value['el_inchikey'] = molecule.inchikey
        value['el_smiles'] = molecule.cano_smiles
        value['el_type'] = 'molecule' if value['el_type'].nil?
        value['el_iupac'] = molecule.iupac_name
        value['el_molecular_weight'] = molecule.molecular_weight
        value
      rescue StandardError => e
        Labimotion.log_exception(e)
        value
      end

      def proc_assign_sample(value, sample)
        return {} if sample.nil?

        value = {} if value.nil? || value.is_a?(String)
        value['el_id'] = sample.id
        value['el_type'] = 'sample' if value['el_type'].nil?
        value['el_tip'] = sample.short_label
        value['el_label'] = sample.short_label
        value['el_svg'] = sample.get_svg_path
        value
      rescue StandardError => e
        Labimotion.log_exception(e)
        value
      end

      def proc_assign_element(value, element)
        return {} if element.nil?

        value = {} if value.nil? || value.is_a?(String)
        value['el_id'] = element.id
        value['el_type'] = 'element' if value['el_type'].nil?
        value['el_tip'] = element.short_label
        value['el_label'] = element.short_label
        value
      rescue StandardError => e
        Labimotion.log_exception(e)
        value
      end

      def proc_assign_upload(value, attachment)
        return {} if attachment.nil?

        value = {} if value.nil? || value.is_a?(String)
        value['aid'] = attachment.id
        value['uid'] = attachment.identifier
        value['filename'] = attachment.filename
        value
      rescue StandardError => e
        Labimotion.log_exception(e)
        value
      end


      def proc_table_molecule(properties, data, svalue, key, tidx, vdx, col_id)
        return properties unless id = svalue.fetch('el_id', nil)

        molfile = data.fetch(Labimotion::Prop::MOLECULE, nil)&.fetch(id, nil)&.fetch('molfile', nil)
        tmol = Molecule.find_or_create_by_molfile(molfile) if molfile.present?
        val = properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][tidx]['sub_values'][vdx][col_id]['value']
        properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][tidx]['sub_values'][vdx][col_id]['value'] = proc_assign_molecule(val, tmol)
        properties
      rescue StandardError => e
        Labimotion.log_exception(e)
        properties
      end

      def proc_table_sample(properties, data, instances, svalue, key, tidx, vdx, col_id)
        return properties unless id = svalue.fetch('el_id', nil)

        # orig_s = data.fetch(Labimotion::Prop::SAMPLE, nil)&.fetch(svalue['el_id'], nil)
        sample = instances.fetch(Labimotion::Prop::SAMPLE, nil)&.fetch(id, nil)
        val = properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][tidx]['sub_values'][vdx][col_id]['value']
        properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][tidx]['sub_values'][vdx][col_id]['value'] = proc_assign_sample(val, sample)
        properties
      rescue StandardError => e
        Labimotion.log_exception(e)
        properties
      end

      def proc_table_prop(layer, key, data, instance, properties, field, tidx, type)
        fields = field[Labimotion::Prop::SUBFIELDS].select { |ss| ss['type'] == type }
        return properties if fields.nil?

        col_ids = fields.map { |x| x.values[0] }
        col_ids.each do |col_id|
          next if field[Labimotion::Prop::SUBVALUES].nil?

          field[Labimotion::Prop::SUBVALUES].each_with_index do |sub_value, vdx|
            next unless sub_value.fetch(col_id, nil)&.fetch('value', nil).is_a?(Hash)

            next if sub_value.fetch(col_id, nil)&.fetch('value', nil)&.fetch('el_id', nil).nil?

            svalue = sub_value.fetch(col_id, nil)&.fetch('value', nil)
            next if svalue.fetch('el_id', nil).nil? ## || svalue.fetch('el_inchikey', nil).nil? (molecule only?)

            case type
            when Labimotion::FieldType::DRAG_MOLECULE
              properties = proc_table_molecule(properties, data, svalue, key, tidx, vdx, col_id)
            when Labimotion::FieldType::DRAG_SAMPLE
              properties = proc_table_sample(properties, data, instance, svalue, key, tidx, vdx, col_id)
            end
          end
        end
        properties
      rescue StandardError => e
        Labimotion.log_exception(e)
        properties
      end
    end

    def self.proc_sample(layer, key, data, instances, properties)
      fields = layer[Labimotion::Prop::FIELDS].select { |ss| ss['type'] == Labimotion::FieldType::DRAG_SAMPLE }
      fields.each do |field|
        idx = properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS].index(field)
        id = field["value"] && field["value"]["el_id"] unless idx.nil?
        sample = instances.fetch(Labimotion::Prop::SAMPLE, nil)&.fetch(id, nil)
        val = properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value']
        val = proc_assign_sample(val, sample)
        properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value'] = val
      end
      properties
    rescue StandardError => e
      Labimotion.log_exception(e)
      raise
    end

    def self.proc_element(layer, key, data, instances, properties, elements)
      fields = layer[Labimotion::Prop::FIELDS].select { |ss| ss['type'] == Labimotion::FieldType::DRAG_ELEMENT }
      fields.each do |field|
        idx = properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS].index(field)
        id = field["value"] && field["value"]["el_id"] unless idx.nil?
        att_el = (elements && elements[id]) || instances.fetch(Labimotion::Prop::L_ELEMENT, nil)&.fetch(id, nil)
        if att_el.nil?
          properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value'] = {}
        else
          val = properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value']
          val = proc_assign_element(val, att_el)
          properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value'] = val
        end
      end
      properties
    rescue StandardError => e
      Labimotion.log_exception(e)
      raise
    end

    def self.proc_upload(layer, key, data, instances, attachments, element)
      properties = element.properties
      upload_type = upload_type(element)
      return if upload_type.nil?

      fields = layer[Labimotion::Prop::FIELDS].select { |ss| ss['type'] == Labimotion::FieldType::UPLOAD }
      fields.each do |field|
        idx = properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS].index(field)
        next if idx.nil?

        files = field["value"] && field["value"]["files"]
        files&.each_with_index do |fi, fdx|
          aid = properties['layers'][key]['fields'][idx]['value']['files'][fdx]['aid']
          uid = properties['layers'][key]['fields'][idx]['value']['files'][fdx]['uid']
          att = data.fetch('Attachment', nil)&.fetch(aid, nil)
          attachment = Attachment.find_by('id IN (?) AND filename LIKE ? ', attachments, uid << '%')
          next if attachment.nil? || att.nil?

          attachment.update!(attachable_id: element.id, attachable_type: upload_type, transferred: true, aasm_state: att['aasm_state'], filename: att['filename'])
          val = properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value']['files'][fdx]
          val = proc_assign_upload(val, attachment)
          properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value']['files'][fdx] = val
        end
      end
      properties
    rescue StandardError => e
      Labimotion.log_exception(e)
      properties
    end

    def self.proc_molecule(layer, key, data, properties)
      fields = layer[Labimotion::Prop::FIELDS].select { |ss| ss['type'] == Labimotion::FieldType::DRAG_MOLECULE }
      fields.each do |field|
        idx = properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS].index(field)
        next if idx.nil? || field.fetch('value', nil).nil?

        next unless field.fetch('value', nil).is_a?(Hash)

        id = field.fetch('value', nil)&.fetch('el_id', nil) unless idx.nil?
        molfile = data.fetch(Labimotion::Prop::MOLECULE, nil)&.fetch(id, nil)&.fetch('molfile', nil) unless id.nil?
        next if molfile.nil?

        mol = Molecule.find_or_create_by_molfile(molfile)
        val = properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value']
        properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value'] = proc_assign_molecule(val, mol)
      end
      properties
    rescue StandardError => e
      Labimotion.log_exception(e)
      raise
    end


    def self.proc_table(layer, key, data, instance, properties)
      fields = layer[Labimotion::Prop::FIELDS].select { |ss| ss['type'] == Labimotion::FieldType::TABLE }
      fields&.each do |field|
        tidx = layer[Labimotion::Prop::FIELDS].index(field)
        next unless field['sub_values'].present? && field[Labimotion::Prop::SUBFIELDS].present?

        proc_table_prop(layer, key, data, instance, properties, field, tidx, Labimotion::FieldType::DRAG_MOLECULE)
        proc_table_prop(layer, key, data, instance, properties, field, tidx, Labimotion::FieldType::DRAG_SAMPLE)
      end
      properties
    rescue StandardError => e
      Labimotion.log_exception(e)
      raise
    end

    def self.properties_handler(data, instances, attachments, elmenet, elements)
      properties = elmenet.properties
      properties.fetch(Labimotion::Prop::LAYERS, nil)&.keys&.each do |key|
        layer = properties[Labimotion::Prop::LAYERS][key]
        properties = proc_molecule(layer, key, data, properties)
        properties = proc_upload(layer, key, data, instances, attachments, elmenet)
        properties = proc_sample(layer, key, data, instances, properties)
        properties = proc_element(layer, key, data, instances, properties, elements) # unless elements.nil?
        properties = proc_table(layer, key, data, instances, properties)
      end
      properties
    rescue StandardError => e
      Labimotion.log_exception(e)
      raise
    end

    def self.process_ai(data, instances)
      ai_has_changed = false
      instances&.fetch(Labimotion::Prop::L_ELEMENT, nil)&.each do |uuid, element|
        properties = element.properties
        properties.fetch(Labimotion::Prop::LAYERS, nil)&.keys&.each do |key|
          layer = properties[Labimotion::Prop::LAYERS][key]
          layer.fetch('ai', nil)&.each_with_index do |ai_key, idx|
            ana = instances.fetch(Labimotion::Prop::CONTAINER)&.fetch(ai_key, nil)
            properties[Labimotion::Prop::LAYERS][key]['ai'][idx] = ana.id unless ana.nil?
            ai_has_changed = true
          end
        end
        element.update_columns(properties: properties) if ai_has_changed
      end
    rescue StandardError => e
      Labimotion.log_exception(e)
      raise
    end

    def self.create_segment_klass(sk_obj, segment_klass, element_klass, current_user_id)
      return if segment_klass.present? || element_klass.nil? || sk_obj.nil?

      segment_klass = Labimotion::SegmentKlass.create!(sk_obj.slice(
          'label',
          'desc',
          'properties_template',
          'is_active',
          'place',
          'properties_release',
          'uuid',
          'identifier',
          'sync_time'
        ).merge(
          element_klass: element_klass,
          created_by: current_user_id,
          released_at: DateTime.now
        )
      )

      segment_klass
    end
  end
end
