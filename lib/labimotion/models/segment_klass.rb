# frozen_string_literal: true

require 'labimotion/models/concerns/generic_klass_revisions'
require 'labimotion/models/concerns/generic_klass'
require 'labimotion/models/concerns/workflow'
require 'labimotion/models/concerns/metadata_validation'

module Labimotion
  class SegmentKlass < ApplicationRecord
    self.table_name = :segment_klasses
    acts_as_paranoid
    include GenericKlassRevisions
    include GenericKlass
    include Workflow
    include MetadataValidation
    belongs_to :element_klass, class_name: 'Labimotion::ElementKlass'
    has_many :segments, dependent: :destroy, class_name: 'Labimotion::Segment'
    has_many :segment_klasses_revisions, dependent: :destroy, class_name: 'Labimotion::SegmentKlassesRevision'

    validates :label, presence: true, uniqueness: { scope: :element_klass_id, conditions: -> { where(deleted_at: nil) }, message: 'is already in use.' }

    # Scope for displayed_in_list - select only necessary columns for list view
    scope :for_list_display, lambda {
      select(:id, :uuid, :label, :desc, :is_active, :version, :place, :released_at,
             :identifier, :sync_time, :created_at, :updated_at, :element_klass_id)
    }

    def self.gen_klasses_json
      klasses = where(is_active: true)&.pluck(:name) || []
    rescue ActiveRecord::StatementInvalid, PG::ConnectionBad, PG::UndefinedTable
      klasses = []
    ensure
      Rails.root.join('config', 'segment_klass.json').write(klasses&.to_json || [])
    end
  end
end
