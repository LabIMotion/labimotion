# frozen_string_literal: true

module Labimotion
  ## Metadata Validation Concern
  module MetadataValidation
    extend ActiveSupport::Concern

    included do
      validate :metadata_must_be_hash

      # Provide default value for metadata to support migrations
      # when the column might not exist yet
      after_initialize :set_metadata_default
    end

    private

    def set_metadata_default
      self.metadata ||= {} if has_attribute?(:metadata)
    end

    def metadata_must_be_hash
      # Skip validation if the metadata column doesn't exist yet (during migrations)
      return unless has_attribute?(:metadata)

      # Set default if nil
      self.metadata ||= {}

      return if metadata.is_a?(Hash)

      errors.add(:metadata, 'must be a hash/object, not an array or other type')
    end
  end
end
