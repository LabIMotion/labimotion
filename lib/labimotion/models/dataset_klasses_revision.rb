# frozen_string_literal: true

module Labimotion
  class DatasetKlassesRevision < ApplicationRecord
    self.table_name = :dataset_klasses_revisions
    acts_as_paranoid
    has_one :dataset_klass, class_name: 'Labimotion::DatasetKlass'
  end
end
