# frozen_string_literal: true

module Labimotion
  class VocabularyHandler
    class << self
      def update_vocabularies(properties, current_user, element)
        properties[Labimotion::Prop::LAYERS].each do |key, layer|
          update_layer_vocabularies(layer, key, properties, current_user, element)
        end
        properties
      rescue StandardError => e
        Labimotion.log_exception(e, current_user)
        properties
      end

      def load_all_vocabularies
        load_from_files + load_from_database
      end

      def load_app_vocabularies
        load_from_files
      end

      private

      def update_layer_vocabularies(layer, key, properties, current_user, element)
        field_vocabularies = layer[Labimotion::Prop::FIELDS].select { |field| field['is_voc'] }
        field_vocabularies.each do |field|
          idx = layer[Labimotion::Prop::FIELDS].index(field)
          val = get_vocabulary_value(field, current_user, element)
          update_field_value(properties, key, idx, val) if val.present?
        end
      end

      def get_vocabulary_value(field, current_user, element)
        case field['source']
        when 'System'
          get_system_value(field)
        when 'User'
          get_user_value(field, current_user)
        when 'Element'
          get_element_value(field, element)
        when 'Segment'
          get_segment_value(field, element)
        when 'Dataset'
          # TODO: Implement Dataset logic here
          nil
        end
      end

      def get_system_value(field)
        current_time = Time.now.strftime('%d/%m/%Y %H:%M')
        case field['identifier']
        when 'dateTime-update'
          current_time
        when 'dateTime-create'
          current_time if field['value'].blank?
        end
      end

      def get_user_value(field, current_user)
        current_user.name if field['identifier'] == 'user-name' && current_user.present?
      end

      def get_element_value(field, element)
        case field['identifier']
        when 'element-id'
          element.id.to_s
        when 'element-short_label'
          element.short_label if element.has_attribute?(:short_label)
        when 'element-name'
          element.name if element.has_attribute?(:name)
        when 'element-class'
          element.class.name === 'Labimotion::Element' ? element.element_klass.label : element.class.name
        else
          ek = element.element_klass
          return if ek.nil? || ek.identifier != field['source_id']

          el_prop = element.properties
          fields = el_prop[Labimotion::Prop::LAYERS][field['layer_id']][Labimotion::Prop::FIELDS]
          fields.find { |ss| ss['field'] == field['field_id'] }&.dig('value')
        end
      end

      def get_segment_value(field, element)
        segments = element.segments.joins(:segment_klass).find_by('segment_klasses.identifier = ?', field['source_id'])
        return if segments.nil?

        seg_prop = segments.properties
        fields = seg_prop[Labimotion::Prop::LAYERS][field['layer_id']][Labimotion::Prop::FIELDS]
        fields.find { |ss| ss['field'] == field['field_id'] }&.dig('value')
      end

      def update_field_value(properties, key, idx, val)
        properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value'] = val
        properties
      end

      def load_from_files
        merged_data = []
        merged_data.concat(load_json_file('System.json'))
        merged_data.concat(load_json_file('Standard.json'))
        merged_data
      end

      def load_json_file(filename)
        file_path = File.join(__dir__, 'data', 'vocab', filename)
        file_content = File.read(file_path)
        JSON.parse(file_content)
      end

      def load_from_database
        vocabularies = Labimotion::Vocabulary.all.sort_by(&:name)
        Labimotion::VocabularyEntity.represent(vocabularies, serializable: true)
      end
    end
  end
end