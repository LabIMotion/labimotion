# frozen_string_literal: true
#
require 'labimotion/entities/generic_klass_entity'

module Labimotion
  # ElementKlassEntity
  class ElementKlassEntity < GenericKlassEntity
    expose :name, :icon_name, :klass_prefix, :is_generic
  end
end
