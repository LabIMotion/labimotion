# frozen_string_literal: true

module Labimotion
  class ElementsSample < ApplicationRecord
    acts_as_paranoid
    self.table_name = :elements_samples
    has_one :element, class_name: 'Labimotion::Element'
    belongs_to :sample
    include Tagging
  end
end
