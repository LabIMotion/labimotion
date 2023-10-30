# frozen_string_literal: true
require 'labimotion/models/concerns/generic_klass_revisions'
require 'labimotion/models/concerns/workflow'

module Labimotion
  class SegmentKlass < ApplicationRecord
    self.table_name = :segment_klasses
    acts_as_paranoid
    include GenericKlassRevisions
    include Workflow
    belongs_to :element_klass, class_name: 'Labimotion::ElementKlass'
    has_many :segments, dependent: :destroy, class_name: 'Labimotion::Segment'
    has_many :segment_klasses_revisions, dependent: :destroy, class_name: 'Labimotion::SegmentKlassesRevision'

    def self.gen_klasses_json
      klasses = where(is_active: true)&.pluck(:name) || []
    rescue ActiveRecord::StatementInvalid, PG::ConnectionBad, PG::UndefinedTable
      klasses = []
    ensure
      File.write(
        Rails.root.join('config', 'segment_klass.json'),
        klasses&.to_json || []
      )
    end
  end
end
