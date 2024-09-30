# frozen_string_literal: true

module Labimotion
  # Helper for associated sample
  module VocabularyHelpers
    extend Grape::API::Helpers

    def update_vocabularies(properties, current_user, element)
      Labimotion::VocabularyHandler.update_vocabularies(properties, current_user, element)
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      properties
    end

  end
end
