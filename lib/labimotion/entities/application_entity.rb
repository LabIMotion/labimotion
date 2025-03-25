# frozen_string_literal: true

module Labimotion
  ## ApplicationEntity
  # This class serves as the base entity for the Labimotion module,
  # inheriting from the core ApplicationEntity and providing custom formatting.
  class ApplicationEntity < ::Entities::ApplicationEntity
    # Common condition for fields that should not be displayed in list views
    DISPLAYED_IN_LIST_CONDITION = { unless: :displayed_in_list }.freeze

    format_with(:eln_timestamp) do |datetime|
      datetime.present? ? datetime.strftime('%Y-%m-%d %H:%M:%S %Z') : nil
    end
  end
end
