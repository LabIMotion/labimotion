# frozen_string_literal: true

require 'erb'

module Labimotion
  # Builds the DataCite (kernel-4) metadata XML for a LabIMotion template DOI.
  # The same XML is uploaded to DataCite at release time and shown in the UI
  # preview, so what users see is exactly what gets sent. A template has a
  # single DOI; the ERB template binds to this instance, so the methods below
  # are its accessors.
  class BuildTemplateDoiXml
    include ::DataCitePublisher

    TEMPLATE_PATH = Rails.root.join('app/publish/datacite_metadata_labimotion_template.html.erb')

    RESOURCE_LABEL = {
      'element' => 'LabIMotion Element Template',
      'segment' => 'LabIMotion Segment Template',
      'dataset' => 'LabIMotion Dataset Template'
    }.freeze

    def initialize(record, doi = nil, current_user = nil)
      @record = record
      @doi = doi || ::Doi.labimotion_latest_doi(record)
      @current_user = current_user
    end

    # Returns the XML string, or nil when no DOI has been reserved yet.
    def call
      return nil if @doi.nil?

      ERB.new(File.read(TEMPLATE_PATH), trim_mode: '-').result(binding)
    end

    private

    def full_doi
      @doi.full_doi
    end

    def title
      h(publication['title'].presence || @record.label.presence || @record.try(:name))
    end

    def description
      h(publication['description'])
    end

    # The DOI version this DOI was reserved for (kept on the DOI), so each
    # DOI's XML keeps showing its own version even after the template moves on.
    def version
      h(::Doi.labimotion_doi_version(@doi).presence || ::Doi.labimotion_version_segment(@record))
    end

    def license
      h(publication['license'].presence || 'CC-BY-4.0')
    end

    def resource_label
      RESOURCE_LABEL[TemplateDoiHelpers.klass_type_for(@record)]
    end

    def publication_year
      (@doi.minted_at || Time.current).strftime('%Y')
    end

    def creators
      Array(publication['authors']).filter_map do |author|
        next unless author.is_a?(Hash)

        given = author['givenName'].to_s.strip
        family = author['familyName'].to_s.strip
        next if given.empty? && family.empty?

        { 'givenName' => h(given), 'familyName' => h(family),
          'orcid' => h(author['orcid'].to_s.strip), 'affiliation' => h(author['affiliation'].to_s.strip) }
      end
    end

    # The acting user, rendered as a DataCite "Researcher" contributor. Nil
    # (no contributors block) when there is no user or they have no name.
    def contributor
      user = @current_user
      return nil unless user

      given = user.try(:first_name).to_s.strip
      family = user.try(:last_name).to_s.strip
      return nil if given.empty? && family.empty?

      orcid = user.respond_to?(:orcid) ? user.orcid.to_s.strip : ''
      { 'givenName' => h(given), 'familyName' => h(family), 'orcid' => h(orcid) }
    end

    def publication
      @publication ||=
        (@record.properties_template.is_a?(Hash) ? @record.properties_template['publication'] : nil) || {}
    end

    def h(value)
      ERB::Util.html_escape(value.to_s)
    end
  end
end
