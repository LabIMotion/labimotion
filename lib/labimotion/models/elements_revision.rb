
module Labimotion
  class ElementsRevision < ApplicationRecord
    self.table_name = :elements_revisions
    acts_as_paranoid
    has_one :element, class_name: 'Labimotion::Element'
  end
end
