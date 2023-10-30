# frozen_string_literal: true

require 'labimotion/models/concerns/workflow'

module Labimotion
  class ElementKlassesRevision < ApplicationRecord
    acts_as_paranoid
    self.table_name = :element_klasses_revisions
    include Workflow
    has_one :element_klass, class_name: 'Labimotion::ElementKlass'


    def migrate_workflow
      return if properties_release.nil? || properties_release['flow'].nil?

      update_column(:properties_release, split_workflow(properties_release)) if properties_release['flow']
    end
  end
end
