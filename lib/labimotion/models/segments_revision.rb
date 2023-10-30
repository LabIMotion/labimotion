# frozen_string_literal: true

module Labimotion
  class SegmentsRevision < ApplicationRecord
    acts_as_paranoid
    self.table_name = :segments_revisions
    has_one :segment, class_name: 'Labimotion::Segment'
  end
end
