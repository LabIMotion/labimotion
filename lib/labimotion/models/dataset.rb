# frozen_string_literal: true
require 'labimotion/models/concerns/generic_revisions'

# ## This is the first version of the dataset class
module Labimotion
  # ## This is the first version of the dataset class
  class Dataset < ApplicationRecord
    self.table_name = :datasets
    acts_as_paranoid
    include GenericRevisions
    belongs_to :dataset_klass, class_name: 'Labimotion::DatasetKlass'
    belongs_to :element, polymorphic: true, class_name: 'Labimotion::Element'
  end
end
