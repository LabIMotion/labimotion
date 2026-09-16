# frozen_string_literal: true

module Labimotion
  # Reserves a DataCite DOI for a LabIMotion template (ElementKlass /
  # SegmentKlass / DatasetKlass). A DOI is published per major release
  # (template X.0 -> DOI vX; later minor revisions X.y roll into v(X+1));
  # sub-1.0 and unversioned templates map to the first DOI (v1). The existing
  # DOI is returned unless the latest one has been released AND the template
  # has since moved to a version that maps to a new DOI version.
  class ReserveTemplateDoi
    include TemplateDoiHelpers

    attr_reader :record, :current_user, :doi, :error

    def initialize(record, current_user)
      @record = record
      @current_user = current_user
    end

    def call
      return failure('record is required') if record.nil?
      return failure('unauthorized') unless TemplateDoiHelpers.authorized?(record, current_user)

      @doi = reserve
      self
    end

    def success?
      @error.nil? && @doi.present?
    end

    private

    # Returns the template's current DOI, or reserves one for a new version.
    # A new DOI is only created when there is none yet, or once the latest DOI
    # has been released and the template has moved to a new version. Otherwise
    # the existing DOI is returned, so repeated reserves are idempotent and a
    # released version stays read-only until the template is revised.
    def reserve
      latest = ::Doi.labimotion_latest_doi(record)
      return latest if latest && !TemplateDoiHelpers.new_version_available?(record)

      create_doi
    end

    def create_doi
      suffix = ::Doi.build_labimotion_suffix(record)
      return failure('could not build a DOI suffix for this template') if suffix.blank?

      # Set inchikey == suffix and version_count: 0 so Doi#align_suffix keeps
      # the deterministic suffix verbatim (no /concept, no rebuild).
      ::Doi.create!(
        doiable_id: record.id,
        doiable_type: record.class.name,
        inchikey: suffix,
        suffix: suffix,
        version_count: 0,
        metadata: ::Doi.labimotion_doi_metadata(record)
      )
    rescue ActiveRecord::RecordInvalid => e
      failure(e.message)
      nil
    end

    def failure(message)
      @error = message
      self
    end
  end
end
