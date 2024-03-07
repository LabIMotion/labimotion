# frozen_string_literal: true

module Labimotion
  class PropertiesHandler
    class << self
      private

      def check_val(field, type)
        case type
        when Labimotion::FieldType::DRAG_SAMPLE, Labimotion::FieldType::DRAG_ELEMENT
          return field.dig('value', 'el_id').present?
        when Labimotion::FieldType::UPLOAD
          return field.dig('value', 'files')&.length&.positive?
        when Labimotion::FieldType::TABLE
          return field[Labimotion::Prop::SUBFIELDS]&.length&.positive? && field['sub_values']&.length&.positive?
        end
        false
      rescue StandardError => e
        Labimotion.log_exception(e)
        false
      end

      def detach_val(properties, field, key, type)
        case type
        when Labimotion::FieldType::DRAG_SAMPLE, Labimotion::FieldType::DRAG_ELEMENT, Labimotion::FieldType::UPLOAD
          idx = properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS].index(field)
          properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value'] = {}
        when Labimotion::FieldType::TABLE
          return properties if check_table_val(field)

          idx = properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS].index(field)
          properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['sub_values'] = []
        end
        properties
      rescue StandardError => e
        Labimotion.log_exception(e)
        properties
      end

      def check_table_val(field)
        tsf_samples = field[Labimotion::Prop::SUBFIELDS].select { |ss| ss['type'] == Labimotion::FieldType::DRAG_SAMPLE }
        tsf_elements = field[Labimotion::Prop::SUBFIELDS].select { |ss| ss['type'] == Labimotion::FieldType::DRAG_ELEMENT }
        tsf_samples.length.zero? && tsf_elements.length.zero?
      rescue StandardError => e
        Labimotion.log_exception(e)
        false
      end
    end

    def self.check_properties(properties)
      properties.nil? || !properties.is_a?(Hash) || properties[Labimotion::Prop::LAYERS].nil? || properties[Labimotion::Prop::LAYERS].keys.empty?
    end

    def self.detach(properties, key, type)
      fields = properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS].select { |ss| ss['type'] == type }
      fields.each do |field|
        next unless check_val(field, type)

        properties = detach_val(properties, field, key, type)
      end
      properties
    rescue StandardError => e
      Labimotion.log_exception(e)
      properties
    end

    def self.split(properties, key, type)
      fields = properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS].select { |ss| ss['type'] == type }
      fields.each do |field|
        next unless check_val(field, type)

        idx = properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS].index(field)
        ## TODO Split ...
      end
      properties
    rescue StandardError => e
      Labimotion.log_exception(e)
      properties
    end

    def self.copy(properties, key, type)
      fields = properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS].select { |ss| ss['type'] == type }
      fields.each do |field|
        next unless check_val(field, type)

        idx = properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS].index(field)
        ## TODO Copy Sample...
      end
      properties
    rescue StandardError => e
      Labimotion.log_exception(e)
      properties
    end
  end
end
