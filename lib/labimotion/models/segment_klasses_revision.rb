# frozen_string_literal: true

require 'labimotion/models/concerns/klass_revision'
require 'labimotion/models/concerns/metadata_validation'

module Labimotion
  class SegmentKlassesRevision < ApplicationRecord
    acts_as_paranoid
    self.table_name = :segment_klasses_revisions
    include KlassRevision
    include MetadataValidation
    belongs_to :segment_klass, class_name: 'Labimotion::SegmentKlass'
  end
end
