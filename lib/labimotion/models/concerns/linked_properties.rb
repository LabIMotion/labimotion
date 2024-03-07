module Labimotion
  # Segmentable concern
  module LinkedProperties
    extend ActiveSupport::Concern

    def detach_properties(properties)
      return properties if Labimotion::PropertiesHandler.check_properties(properties)

      properties[Labimotion::Prop::LAYERS]&.keys&.each do |key|
        properties = Labimotion::PropertiesHandler.detach(properties, key, Labimotion::FieldType::DRAG_SAMPLE)
        properties = Labimotion::PropertiesHandler.detach(properties, key, Labimotion::FieldType::DRAG_ELEMENT)
        properties = Labimotion::PropertiesHandler.detach(properties, key, Labimotion::FieldType::UPLOAD)
        properties = Labimotion::PropertiesHandler.detach(properties, key, Labimotion::FieldType::TABLE)
      end
      properties
    end
  end
end
