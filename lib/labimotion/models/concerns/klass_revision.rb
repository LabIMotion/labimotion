# frozen_string_literal: true

module Labimotion
  # Shared concern for all Klass Revision models
  # Provides a unified interface to access the parent klass object
  module KlassRevision
    extend ActiveSupport::Concern

    # Returns the associated klass object (ElementKlass, SegmentKlass, or DatasetKlass)
    def klass
      return element_klass if respond_to?(:element_klass)
      return segment_klass if respond_to?(:segment_klass)
      return dataset_klass if respond_to?(:dataset_klass)

      nil
    end

    # Increments the submitted counter and saves the record
    def increment_submitted!
      increment!(:submitted)
    end
  end
end
