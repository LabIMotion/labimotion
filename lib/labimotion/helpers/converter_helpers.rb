# frozen_string_literal: true
require 'grape'

module Labimotion
  ## ConverterHelpers
  module ConverterHelpers
    extend Grape::API::Helpers

    # Update the general_description field in the container's extended_metadata
    def self.update_general_description(container, current_user, date: nil, time: nil)
      return unless container.present?

      desc = container.extended_metadata['general_description']

      general_desc = desc if desc.present? && desc.is_a?(Hash)
      general_desc = JSON.parse(container.extended_metadata['general_description']) if desc.present? && desc.is_a?(String)
      general_desc = {} unless general_desc.is_a?(Hash)
      general_desc['creator'] = current_user.name if current_user.present?
      general_desc['date'] = date if date.present?
      general_desc['time'] = time if time.present?

      container.extended_metadata['general_description'] = general_desc.to_json
      container.save!
    end
  end
end
