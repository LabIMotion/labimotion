# frozen_string_literal: true

module Labimotion
  class ElementsWellplate < ApplicationRecord
    acts_as_paranoid
    self.table_name = :elements_wellplates
    belongs_to :element, class_name: 'Labimotion::Element'
    belongs_to :wellplate
  end
end
