# frozen_string_literal: true

require 'labimotion/entities/generic_klass_entity'
module Labimotion
  class DatasetKlassEntity < Labimotion::GenericKlassEntity
    expose(
      :ols_term_id
    )
  end
end
