# frozen_string_literal: true

require 'labimotion/conf'
require 'labimotion/models/concerns/generic_klass_revisions'
require 'labimotion/models/concerns/generic_klass'
require 'labimotion/models/concerns/workflow'
require 'labimotion/models/concerns/metadata_validation'

module Labimotion
  class ElementKlass < ApplicationRecord
    self.table_name = :element_klasses
    acts_as_paranoid
    include GenericKlassRevisions
    include GenericKlass
    include Workflow
    include MetadataValidation
    has_many :elements, dependent: :destroy, class_name: 'Labimotion::Element'
    has_many :segment_klasses, dependent: :destroy, class_name: 'Labimotion::SegmentKlass'
    has_many :element_klasses_revisions, dependent: :destroy, class_name: 'Labimotion::ElementKlassesRevision'

    validates :name, presence: true, uniqueness: { conditions: -> { where(deleted_at: nil) }, message: 'is already in use.' }

    # Scope for displayed_in_list - select only necessary columns for list view
    scope :for_list_display, lambda {
      select(:id, :uuid, :label, :desc, :is_active, :version, :place, :released_at,
             :identifier, :sync_time, :created_at, :updated_at, :name, :icon_name,
             :klass_prefix, :is_generic)
    }

    def self.gen_klasses_json
      klasses = where(is_active: true, is_generic: true).order('place')&.pluck(:name) || []
    rescue ActiveRecord::StatementInvalid, PG::ConnectionBad, PG::UndefinedTable
      klasses = []
    ensure
      File.write(
        # Rails.root.join('app/packs/klasses.json'),
        Labimotion::KLASSES_JSON,
        klasses&.to_json || []
      )
    end
  end
end
