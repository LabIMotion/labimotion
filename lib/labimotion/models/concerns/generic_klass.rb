# frozen_string_literal: true

module Labimotion
  ## Generic Klass Helpers
  module GenericKlass
    extend ActiveSupport::Concern

    included do
      # Scope for active and released templates
      scope :active_and_released, -> { for_list_display.where(is_active: true).where.not(released_at: nil) }

      # Scope for active, released, and generic templates (primarily for ElementKlass)
      scope :active_released_generic, -> { active_and_released.where(is_generic: true) }
    end
  end
end
