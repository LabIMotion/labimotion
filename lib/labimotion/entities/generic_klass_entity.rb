# frozen_string_literal: true

require 'labimotion/entities/application_entity'
module Labimotion
  class GenericKlassEntity < Labimotion::ApplicationEntity
    expose :id, :uuid, :label, :desc, :is_active, :version, :place
    expose :released_at, :identifier, :sync_time

    expose :properties_template, **DISPLAYED_IN_LIST_CONDITION, anonymize_with: {}
    expose :properties_release, **DISPLAYED_IN_LIST_CONDITION, anonymize_with: {}
    expose :metadata, **DISPLAYED_IN_LIST_CONDITION, anonymize_with: {}
    expose_timestamps(timestamp_fields: %i[released_at created_at updated_at sync_time])
  end
end
