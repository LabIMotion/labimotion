# frozen_string_literal: true

require 'labimotion/models/concerns/generic_klass_revisions'
require 'labimotion/models/concerns/generic_klass'
require 'labimotion/models/concerns/metadata_validation'

module Labimotion
  class DatasetKlass < ApplicationRecord
    acts_as_paranoid
    self.table_name = :dataset_klasses
    include GenericKlassRevisions
    include GenericKlass
    include MetadataValidation

    has_many :datasets, dependent: :destroy, class_name: 'Labimotion::Dataset'
    has_many :dataset_klasses_revisions, dependent: :destroy, class_name: 'Labimotion::DatasetKlassesRevision'

    # Scope for displayed_in_list - select only necessary columns for list view
    scope :for_list_display, lambda {
      select(:id, :uuid, :label, :desc, :is_active, :version, :place, :released_at,
             :identifier, :sync_time, :created_at, :updated_at, :ols_term_id)
    }

    def self.init_seeds
      seeds_path = File.join(Rails.root, 'db', 'seeds', 'json', 'dataset_klasses.json')
      seeds = JSON.parse(File.read(seeds_path))

      seeds['chmo'].each do |term|
        next if Labimotion::DatasetKlass.where(ols_term_id: term['id']).any?

        attributes = { ols_term_id: term['id'], label: "#{term['label']} (#{term['synonym']})",
                       desc: "#{term['label']} (#{term['synonym']})", place: term['position'],
                       created_by: Admin.first&.id || 0 }
        Labimotion::DatasetKlass.create!(attributes)
      end
      true
    end

    def self.find_by_mode(ols_term_id, mode)
      where(
        "super_class_of @> jsonb_build_object(:id, jsonb_build_object('mode', :mode))",
        id: ols_term_id,
        mode: mode.to_s
      )
    end

    def self.find_assigned_templates(ols_term_id)
      find_by_mode(ols_term_id, 'assigned')
    end

    def self.find_inferred_templates(ols_term_id)
      find_by_mode(ols_term_id, 'inferred')
    end
  end
end
