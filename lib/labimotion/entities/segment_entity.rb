# frozen_string_literal: true

require 'labimotion/entities/application_entity'
require 'labimotion/entities/properties_entity'
module Labimotion
  ## Segment entity
  class SegmentEntity < Labimotion::PropertiesEntity
    expose :id, :segment_klass_id, :element_type, :element_id, :uuid, :klass_uuid, :klass_label
    expose :properties, **DISPLAYED_IN_LIST_CONDITION, anonymize_with: {}
    expose :properties_release, **DISPLAYED_IN_LIST_CONDITION, anonymize_with: {}
    expose :metadata, **DISPLAYED_IN_LIST_CONDITION, anonymize_with: {}

    def klass_label
      object.segment_klass.label
    end
  end
end
