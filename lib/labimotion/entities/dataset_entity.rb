# frozen_string_literal: true

require 'labimotion/entities/application_entity'
require 'labimotion/entities/properties_entity'
module Labimotion
  # Dataset entity
  class DatasetEntity < Labimotion::PropertiesEntity
    expose :id, :dataset_klass_id, :element_id, :element_type
    expose :klass_ols, :klass_label, :klass_uuid
    expose :properties, **DISPLAYED_IN_LIST_CONDITION, anonymize_with: {}
    expose :properties_release, **DISPLAYED_IN_LIST_CONDITION, anonymize_with: {}
    expose :metadata, **DISPLAYED_IN_LIST_CONDITION, anonymize_with: {}

    def klass_ols
      object&.dataset_klass&.ols_term_id
    end

    def klass_label
      object&.dataset_klass&.label
    end
  end
end
