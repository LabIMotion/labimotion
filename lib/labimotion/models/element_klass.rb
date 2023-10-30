# frozen_string_literal: true
require 'labimotion/models/concerns/generic_klass_revisions'
require 'labimotion/models/concerns/workflow'

module Labimotion
  class ElementKlass < ApplicationRecord
    self.table_name = :element_klasses
    acts_as_paranoid
    include GenericKlassRevisions
    include Workflow
    has_many :elements, dependent: :destroy, class_name: 'Labimotion::Element'
    has_many :segment_klasses, dependent: :destroy, class_name: 'Labimotion::SegmentKlass'
    has_many :element_klasses_revisions, dependent: :destroy, class_name: 'Labimotion::ElementKlassesRevision'

    def self.gen_klasses_json
      klasses = where(is_active: true, is_generic: true).order('place')&.pluck(:name) || []
    rescue ActiveRecord::StatementInvalid, PG::ConnectionBad, PG::UndefinedTable
      klasses = []
    ensure
      File.write(
        Rails.root.join('app/packs/klasses.json'),
        klasses&.to_json || []
      )
    end

  end
end
