# frozen_string_literal: true

module Labimotion
  # Merges a normalized "publication" sub-object into the template's
  # properties_template jsonb. Keeps the rest of the jsonb untouched so the
  # labimotion gem's runtime shape stays intact.
  class UpdateTemplatePublicationMetadata
    include TemplateDoiHelpers

    ALLOWED_KEYS = %w[title description authors license].freeze

    attr_reader :record, :current_user, :publication, :error

    def initialize(record, current_user, publication)
      @record = record
      @current_user = current_user
      @publication = publication
    end

    def call
      return failure('record is required') if record.nil?
      return failure('unauthorized') unless TemplateDoiHelpers.authorized?(record, current_user)
      return failure('publication payload must be a hash') unless publication.is_a?(Hash)

      merged = normalized_publication
      props = (record.properties_template || {}).dup
      props['publication'] = merged
      record.update!(properties_template: props)
      @publication = merged
      self
    end

    def success?
      @error.nil?
    end

    private

    def normalized_publication
      slice = publication.stringify_keys.slice(*ALLOWED_KEYS)
      slice['authors'] = Array(slice['authors']).filter_map { |a| normalize_author(a) }
      slice
    end

    def normalize_author(author)
      return nil unless author.is_a?(Hash)

      h = author.stringify_keys.slice('givenName', 'familyName', 'orcid', 'affiliation', 'affiliation_id')
      return nil if h.values_at('givenName', 'familyName').all? { |v| v.to_s.strip.empty? }

      h
    end

    def failure(message)
      @error = message
      self
    end
  end
end
