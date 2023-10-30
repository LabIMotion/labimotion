# frozen_string_literal: true

module Labimotion
  class DatasetsRevision < ApplicationRecord
    acts_as_paranoid
    self.table_name = :datasets_revisions
    has_one :dataset, class_name: 'Labimotion::Dataset'
  end
end
