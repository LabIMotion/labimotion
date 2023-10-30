# frozen_string_literal: true

module Labimotion
  class SegmentKlassesRevision < ApplicationRecord
    acts_as_paranoid
    self.table_name = :segment_klasses_revisions
    has_one :segment_klass, class_name: 'Labimotion::SegmentKlass'
  end
end
