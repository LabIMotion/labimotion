# frozen_string_literal: true

require 'labimotion/entities/application_entity'
module Labimotion
  class KlassRevisionEntity < Labimotion::ApplicationEntity
    expose :id, :uuid, :version, :released_at, :klass_id, :submitted
    expose :properties_release, **DISPLAYED_IN_LIST_CONDITION, anonymize_with: {}
    expose :metadata, **DISPLAYED_IN_LIST_CONDITION, anonymize_with: {}

    def klass_id
      object.klass&.id
    end

    def released_at
      object.released_at&.strftime('%d.%m.%Y, %H:%M')
    end
  end
end
