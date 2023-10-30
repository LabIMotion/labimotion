
module Labimotion
  class ElementsElement < ApplicationRecord
    self.table_name = :elements_elements
    acts_as_paranoid
    belongs_to :element, class_name: 'Labimotion::Element'
    belongs_to :parent, foreign_key: :parent_id, class_name: 'Labimotion::Element'

    # include Tagging
  end
end
