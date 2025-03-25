# frozen_string_literal: true

require 'labimotion/models/concerns/klass_revision'
require 'labimotion/models/concerns/metadata_validation'

module Labimotion
  class DatasetKlassesRevision < ApplicationRecord
    self.table_name = :dataset_klasses_revisions
    acts_as_paranoid
    include KlassRevision
    include MetadataValidation
    belongs_to :dataset_klass, class_name: 'Labimotion::DatasetKlass'
  end
end
