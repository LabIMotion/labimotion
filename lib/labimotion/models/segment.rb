# frozen_string_literal: true
require 'labimotion/models/concerns/generic_revisions'

module Labimotion
  class Segment < ApplicationRecord
    acts_as_paranoid
    self.table_name = :segments
    include GenericRevisions

    belongs_to :segment_klass, class_name: 'Labimotion::SegmentKlass'
    belongs_to :element, polymorphic: true, class_name: 'Labimotion::Element'
    has_many :segments_revisions, dependent: :destroy, class_name: 'Labimotion::SegmentsRevision'
  end
end
