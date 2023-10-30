# frozen_string_literal: true
#
require 'labimotion/entities/application_entity'
module Labimotion
  # Dataset entity
  class DatasetEntity < ApplicationEntity
    expose :id, :dataset_klass_id, :properties, :properties_release, :element_id, :element_type, :klass_ols, :klass_label, :klass_uuid
    def klass_ols
      object&.dataset_klass&.ols_term_id
    end

    def klass_label
      object&.dataset_klass&.label
    end
  end
end
