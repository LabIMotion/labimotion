# frozen_string_literal: true

module Labimotion
  class DoseRespOutput < ApplicationRecord
    acts_as_paranoid
    self.table_name = :dose_resp_outputs

    # Associations
    belongs_to :dose_resp_request, class_name: 'Labimotion::DoseRespRequest'

    # Validations
    validates :dose_resp_request, presence: true
    validates :output_data, presence: true
    validate :output_data_is_hash

    # Scopes
    scope :recent, -> { order(created_at: :desc) }

    private

    def output_data_is_hash
      return if output_data.is_a?(Hash)

      errors.add(:output_data, 'must be a Hash')
    end
  end
end
