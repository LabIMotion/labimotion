# frozen_string_literal: true

require 'labimotion/entities/application_entity'
module Labimotion
  ## Segment entity
  class SegmentEntity < PropertiesEntity
    expose :id, :segment_klass_id, :element_type, :element_id, :properties, :properties_release, :uuid, :klass_uuid, :klass_label

    def klass_label
      object.segment_klass.label
    end
  end
end
