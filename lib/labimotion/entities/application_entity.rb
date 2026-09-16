# frozen_string_literal: true

module Labimotion
  ## ApplicationEntity
  # This class serves as the base entity for the Labimotion module,
  # inheriting from the core ApplicationEntity and providing custom formatting.
  class ApplicationEntity < ::Entities::ApplicationEntity
    # Common condition for fields that should not be displayed in list views
    DISPLAYED_IN_LIST_CONDITION = { unless: :displayed_in_list }.freeze

    # ISO 8601. A zone *name* (strftime '%Z', e.g. "UTC") is not a valid ISO zone designator, so
    # clients parsing it with moment.js fall back to `new Date()` — engine-specific behaviour.
    ELN_TIMESTAMP_FORMAT = '%Y-%m-%dT%H:%M:%S%z'

    format_with(:eln_timestamp) do |datetime|
      datetime.present? ? datetime.strftime(ELN_TIMESTAMP_FORMAT) : nil
    end
  end
end
