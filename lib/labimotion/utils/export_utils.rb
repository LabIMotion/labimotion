# frozen_string_literal: true

module Labimotion
  class ExportUtils
    class << self
      private
      def uid(uuids, key, id)
        return nil if uuids.nil? || key.nil? || id.nil?

        new_id = uuids.fetch(key, nil)&.fetch(id, nil)
        new_id || id
      rescue StandardError => e
        Labimotion.log_exception(e)
        raise
      end

      def el_type(name)
        return nil if name.nil?

        case name
        when Labimotion::FieldType::DRAG_ELEMENT
          Labimotion::Prop::L_ELEMENT
        when Labimotion::FieldType::SYS_REACTION
          Labimotion::Prop::REACTION
        when Labimotion::FieldType::DRAG_SAMPLE
          Labimotion::Prop::SAMPLE
        when Labimotion::FieldType::DRAG_MOLECULE
          Labimotion::Prop::MOLECULE
        end
      rescue StandardError => e
        Labimotion.log_exception(e)
        name
      end

      def fetch_molecule(type, id)
        return if type != Labimotion::FieldType::DRAG_MOLECULE || id.nil?

        molecule = Molecule.find_by(id: id)
        yield(molecule) if molecule.present?
      rescue StandardError => e
        Labimotion.log_exception(e)
        raise
      end

      def set_seg_prop(properties, uuids, key, type, &fetch_one)
        layer = properties[Labimotion::Prop::LAYERS][key]
        fields = layer[Labimotion::Prop::FIELDS].select { |ss| ss['type'] == type }
        fields.each do |field|
          idx = properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS].index(field)
          next unless field.fetch('value', nil).is_a?(Hash)

          id = field.fetch('value', nil)&.fetch('el_id', nil) unless idx.nil?
          next unless id.is_a?(Integer)
          next if properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]&.fetch('value', nil).nil?
          next unless properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value'].is_a?(Hash)

          properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value']['el_id'] = uid(uuids, el_type(type), id)
        end
        properties
      rescue StandardError => e
        Labimotion.log_exception(e)
        properties
      end

      def set_prop(properties, uuids, key, type, &fetch_one)
        layer = properties.fetch(Labimotion::Prop::LAYERS, nil)&.fetch(key, nil)
        return properties if layer.nil?

        fields = layer[Labimotion::Prop::FIELDS]&.select { |ss| ss['type'] == type }
        fields&.each do |field|
          idx = properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS].index(field)
          next unless field.fetch('value', nil).is_a?(Hash)

          id = field.fetch('value', nil)&.fetch('el_id', nil) unless idx.nil?
          fetch_molecule(type, id, &fetch_one)
          next if properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]&.fetch('value', nil).nil?

          next unless properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value'].is_a?(Hash)

          properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value']['el_id'] = uid(uuids, el_type(type), id)
        end
        properties
      rescue StandardError => e
        Labimotion.log_exception(e)
        properties
      end

      def set_ai(instance, properties, uuids, key)
        return properties unless instance.is_a?(Element)

        layer = properties[Labimotion::Prop::LAYERS][key]
        layer&.fetch('ai', nil)&.each_with_index do |ai, idx|
          properties[Labimotion::Prop::LAYERS][key]['ai'][idx] = uid(uuids, Labimotion::Prop::CONTAINER, ai)
        end
        properties
      rescue StandardError => e
        Labimotion.log_exception(e)
        properties
      end

      def set_upload(instance, properties, attachments, uuids, key, type)
        attachments = [] if attachments.nil?
        layer = properties[Labimotion::Prop::LAYERS][key]
        fields = layer[Labimotion::Prop::FIELDS].select { |ss| ss['type'] == type }
        fields.each do |field|
          idx = properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS].index(field)
          files = field.fetch('value', nil)&.fetch('files', nil)
          files&.each_with_index do |fi, fdx|
            att = Attachment.find_by(id: fi['aid'])
            if att.nil?
              properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value']['files'].delete_at(fdx)
            else
              attachments += [att] if att.present?
              uuaid = yield(att, {'attachable_id' => instance.class.name})
              properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value']['files'][fdx]['aid'] = uuaid unless att.nil?
            end
          end
          id = field.fetch('value', nil)&.fetch('el_id', nil) unless idx.nil?
          if properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx].fetch('value', nil).is_a?(Hash)
            properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value']['el_id'] = uid(uuids, el_type(type), id)
          end
        end
        [properties, attachments]
      rescue StandardError => e
        Labimotion.log_exception(e)
        [properties, attachments]
      end


      def set_table_prop(field, uuids, type, &fetch_one)
        fields = field[Labimotion::Prop::SUBFIELDS].select { |ss| ss['type'] == type }
        return field if fields.empty?

        col_ids = fields.map { |x| x.values[0] }
        col_ids&.each do |col_id|
          field['sub_values'].each do |sub_value|
            next unless sub_value.fetch(col_id, nil)&.fetch('value', nil).is_a?(Hash)
            next if sub_value.fetch(col_id, nil)&.fetch('value', nil)&.fetch('el_id', nil).nil?
            next unless id = sub_value[col_id]['value']['el_id']

            fetch_molecule(type, id, &fetch_one)
            sub_value[col_id]['value']['el_id'] = uid(uuids, el_type(type), id)
          end
        end
        field
      rescue StandardError => e
        Labimotion.log_exception(e)
        field
      end

      def set_table(properties, uuids, key, type, &fetch_one)
        layer = properties[Labimotion::Prop::LAYERS][key]
        fields = layer[Labimotion::Prop::FIELDS].select { |ss| ss['type'] == type }
        fields&.each do |field|
          next unless field['sub_values'].present? && field[Labimotion::Prop::SUBFIELDS].present?

          set_table_prop(field, uuids, Labimotion::FieldType::DRAG_MOLECULE, &fetch_one)
          set_table_prop(field, uuids, Labimotion::FieldType::DRAG_SAMPLE, &fetch_one)
        end
        properties
      rescue StandardError => e
        Labimotion.log_exception(e)
        properties
      end
    end

    def self.fetch_seg_properties(segment, uuids)
      properties = segment['properties'] || {}
      properties[Labimotion::Prop::LAYERS].keys.each do |key|
        properties = set_seg_prop(properties, uuids, key, Labimotion::FieldType::DRAG_ELEMENT)
        properties = set_seg_prop(properties, uuids, key, Labimotion::FieldType::DRAG_SAMPLE)
        properties = set_seg_prop(properties, uuids, key, Labimotion::FieldType::SYS_REACTION)
      end
      segment['properties'] = properties
      segment
    rescue StandardError => e
      Labimotion.log_exception(e)
      segment
    end

    def self.fetch_properties(instance, uuids, attachments, &fetch_one)
      attachments = [] if attachments.nil?
      properties = instance.properties
      properties[Labimotion::Prop::LAYERS].keys.each do |key|
        properties = set_ai(instance, properties, uuids, key)
        properties = set_prop(properties, uuids, key, Labimotion::FieldType::DRAG_ELEMENT, &fetch_one)
        properties = set_prop(properties, uuids, key, Labimotion::FieldType::DRAG_MOLECULE, &fetch_one)
        properties = set_prop(properties, uuids, key, Labimotion::FieldType::DRAG_SAMPLE, &fetch_one)
        properties = set_prop(properties, uuids, key, Labimotion::FieldType::SYS_REACTION, &fetch_one)
        properties, attachments = set_upload(instance, properties, attachments, uuids, key, Labimotion::FieldType::UPLOAD, &fetch_one)
        properties = set_table(properties, uuids, key, Labimotion::FieldType::TABLE, &fetch_one)
      end
      instance.properties = properties
      [instance, attachments]
    rescue StandardError => e
      Labimotion.log_exception(e)
      [instance, attachments]
    end
  end
end
