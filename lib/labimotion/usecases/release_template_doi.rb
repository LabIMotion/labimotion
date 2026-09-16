# frozen_string_literal: true

module Labimotion
  # Mints (publishes) a previously reserved DOI for a LabIMotion template
  # via DataCite MDS. On success flips Doi#minted=true and stamps
  # released_by/released_at on the template record.
  class ReleaseTemplateDoi
    include TemplateDoiHelpers

    attr_reader :record, :current_user, :doi, :error

    def initialize(record, current_user)
      @record = record
      @current_user = current_user
    end

    def call
      return failure('record is required') if record.nil?
      return failure('unauthorized') unless TemplateDoiHelpers.authorized?(record, current_user)

      # Release the template's current (highest-sequence) DOI — the one a fresh
      # reserve created or returned.
      @doi = ::Doi.labimotion_latest_doi(record)
      return failure('doi not reserved') if @doi.nil?
      return self if @doi.minted

      return failure('publication metadata is incomplete') unless metadata_ready?

      publish_at_datacite
      self
    end

    def success?
      @error.nil? && @doi&.minted
    end

    private

    def publish_at_datacite
      if send_to_datacite?
        mds = ::Repo::Datacite::Mds.new
        # DataCite requires the metadata to exist before the DOI can be minted.
        metadata = mds.upload_metadata(BuildTemplateDoiXml.new(record, doi, current_user).call)
        return failure(datacite_error('metadata upload', metadata)) unless metadata.is_a?(Net::HTTPSuccess)

        response = mds.mint(doi.full_doi, TemplateDoiHelpers.template_url(record))
        return failure(datacite_error('mint', response)) unless response.is_a?(Net::HTTPSuccess)
      end

      ActiveRecord::Base.transaction do
        doi.update!(minted: true, minted_at: Time.current)
        stamp_release_on_record
      end
    end

    def datacite_error(step, response)
      status = response.respond_to?(:code) ? response.code : 'unknown'
      "datacite #{step} failed (status #{status})"
    end

    # Mirrors Publication#transition_from_doi_registering_to_registered!: only
    # hit DataCite for real on test DOIs or in production publishing. In any
    # other mode (e.g. dev/staging) skip the network call and just mark the
    # DOI released locally.
    def send_to_datacite?
      ENV['DATACITE_MODE'] == 'test' || ENV['PUBLISH_MODE'] == 'production'
    end

    def stamp_release_on_record
      attrs = {}
      attrs[:released_at] = Time.current if record.respond_to?(:released_at)
      attrs[:released_by] = current_user.id if record.respond_to?(:released_by) && current_user
      record.update!(attrs) if attrs.any?
    end

    def metadata_ready?
      publication = record.properties_template.is_a?(Hash) ? record.properties_template['publication'] : nil
      return false unless publication.is_a?(Hash)

      publication['title'].to_s.strip.present? &&
        publication['description'].to_s.strip.present? &&
        Array(publication['authors']).any? { |a| a.is_a?(Hash) && a['familyName'].to_s.strip.present? }
    end

    def failure(message)
      @error = message
      self
    end
  end
end
