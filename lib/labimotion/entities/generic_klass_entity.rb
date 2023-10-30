# frozen_string_literal: true
#
require 'labimotion/entities/application_entity'
module Labimotion
  # GenericKlassEntity
  class GenericKlassEntity < ApplicationEntity
    expose :id, :uuid, :label, :desc, :properties_template, :properties_release, :is_active, :version,
          :place, :released_at, :identifier, :sync_time, :created_by, :updated_by, :created_at, :updated_at
    expose_timestamps(timestamp_fields: [:released_at])
    expose_timestamps(timestamp_fields: [:created_at])
    expose_timestamps(timestamp_fields: [:updated_at])
    expose_timestamps(timestamp_fields: [:sync_time])
  end
end
