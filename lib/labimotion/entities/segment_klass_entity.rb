# frozen_string_literal: true
require 'labimotion/entities/generic_klass_entity'
require 'labimotion/entities/element_klass_entity'
module Labimotion
  class SegmentKlassEntity < Labimotion::GenericKlassEntity
    expose :element_klass, using: Labimotion::ElementKlassEntity
  end
end
