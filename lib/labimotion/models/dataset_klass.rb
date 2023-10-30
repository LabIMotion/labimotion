# frozen_string_literal: true
require 'labimotion/models/concerns/generic_klass_revisions'

module Labimotion
  class DatasetKlass < ApplicationRecord
    acts_as_paranoid
    self.table_name = :dataset_klasses
    include GenericKlassRevisions
    has_many :datasets, dependent: :destroy, class_name: 'Labimotion::Dataset'
    has_many :dataset_klasses_revisions, dependent: :destroy, class_name: 'Labimotion::DatasetKlassesRevision'

    def self.init_seeds
      seeds_path = File.join(Rails.root, 'db', 'seeds', 'json', 'dataset_klasses.json')
      seeds = JSON.parse(File.read(seeds_path))

      seeds['chmo'].each do |term|
        next if Labimotion::DatasetKlass.where(ols_term_id: term['id']).count.positive?

        attributes = { ols_term_id: term['id'], label: "#{term['label']} (#{term['synonym']})", desc: "#{term['label']} (#{term['synonym']})", place: term['position'], created_by: Admin.first&.id || 0 }
        Labimotion::DatasetKlass.create!(attributes)
      end
      true
    end
  end
end
