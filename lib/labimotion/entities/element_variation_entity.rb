# frozen_string_literal: true

require 'labimotion/entities/application_entity'

module Labimotion
  class ElementVariationEntity < Labimotion::ApplicationEntity
    expose :id
    expose :element_id, as: :elementId
    expose :variations
    expose :layout

    def variations
      rows = object.variations_hash
      rows.transform_values do |row|
        next row unless row.is_a?(Hash)

        row.symbolize_keys.slice(:uuid, :name, :properties, :metadata, :segments).tap do |slim|
          slim[:properties] = (slim[:properties] || {})
          slim[:metadata] = (slim[:metadata] || {}).slice('notes', 'analyses', 'group', :notes, :analyses, :group)
          slim[:segments] = (slim[:segments] || {})
        end
      end
    end

    def layout
      object.layout_hash
    end
  end
end
