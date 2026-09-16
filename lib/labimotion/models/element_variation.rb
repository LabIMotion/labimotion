# frozen_string_literal: true

module Labimotion
  class ElementVariation < ApplicationRecord
    self.table_name = :element_variations

    belongs_to :element, class_name: 'Labimotion::Element'

    validates :element_id, uniqueness: true

    def variations_hash
      variations.is_a?(Hash) ? variations : {}
    end

    def layout_hash
      return {} unless self.class.column_names.include?('layout')

      layout.is_a?(Hash) ? layout : {}
    end
  end
end
