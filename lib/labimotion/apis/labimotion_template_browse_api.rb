# frozen_string_literal: true

module Labimotion
  # Public, read-only browsing of released LabIMotion templates for the Template
  # Hub "Find a Template" tab: pick a type, a template, then a release version.
  # Returns every released version (revision) of one template, each with its own
  # properties_release so the frontend can render the example inline.
  # Whitelisted in RepoAPI::PUBLIC_URLS so anonymous hub visitors can use it.
  class LabimotionTemplateBrowseAPI < Grape::API
    KLASS_BY_TYPE = Labimotion::TemplateDoiHelpers::KLASS_BY_TYPE
    KLASS_TYPES = KLASS_BY_TYPE.keys.freeze
    # type => [revision model, foreign key to the klass]
    REVISION_BY_TYPE = {
      'element' => [::Labimotion::ElementKlassesRevision, :element_klass_id],
      'segment' => [::Labimotion::SegmentKlassesRevision, :segment_klass_id],
      'dataset' => [::Labimotion::DatasetKlassesRevision, :dataset_klass_id]
    }.freeze

    # rubocop:disable Metrics/BlockLength
    # The helpers block is large due to the many template/version/DOI shaping helpers.
    helpers do
      def find_template(model, identifier)
        model.find_by(identifier: identifier) || model.find_by(uuid: identifier)
      end

      # Numeric sort key for a "major.minor" version string.
      def version_sort_key(version)
        version.to_s.split('.').map(&:to_i)
      end

      def template_summary(record, type)
        element_klass = record.try(:element_klass)
        {
          type: type,
          identifier: record.try(:identifier),
          uuid: record.try(:uuid),
          name: record.try(:name),
          label: record.try(:label),
          desc: record.try(:desc),
          klass_prefix: record.try(:klass_prefix),
          icon_name: record.try(:icon_name),
          current_version: record.try(:version),
          element_klass: element_klass && { label: element_klass.label, icon_name: element_klass.icon_name }
        }
      end

      def version_entry(version, released_at, uuid, properties_release)
        { version: version, released_at: released_at, uuid: uuid, properties_release: properties_release }
      end

      # The current klass's released version is appended only when no revision
      # already captures it, so the latest is always selectable.
      def append_current?(record, versions)
        record.try(:released_at).present? && versions.none? { |v| v[:version] == record.try(:version) }
      end

      # Drops blank-version entries and orders newest-first.
      def sort_versions(versions)
        versions.reject { |v| v[:version].to_s.strip.empty? }
                .sort_by { |v| version_sort_key(v[:version]) }.reverse
      end

      # All released versions of a template, newest first. Built from the
      # revision snapshots, plus the current klass (see append_current?).
      def released_versions(record, type)
        rev_model, foreign_key = REVISION_BY_TYPE[type]
        scope = rev_model.where(foreign_key => record.id).where.not(released_at: nil)
        versions = scope.map { |rev| version_entry(rev.version, rev.released_at, rev.uuid, rev.properties_release) }
        if append_current?(record, versions)
          versions << version_entry(record.try(:version), record.released_at,
                                    record.try(:uuid), record.try(:properties_release))
        end
        sort_versions(versions)
      end

      # The template's DOI publication metadata (shown alongside the DOI).
      def template_publication(record)
        pub = (record.properties_template || {})['publication']
        pub.is_a?(Hash) ? pub.slice('title', 'description', 'authors', 'license') : {}
      end

      # Released (minted) DOIs of the template, each tagged with its DOI version
      # and its DataCite (kernel-4) metadata XML (the downloadable DOI metadata).
      # The frontend maps a chosen template version to the applicable DOI version
      # and shows/downloads the matching entry.
      def released_dois(record)
        ::Doi.labimotion_dois(record).select(&:minted).map do |doi|
          full = doi.full_doi
          { version: ::Doi.labimotion_doi_version(doi), doi: full,
            doi_url: "https://dx.doi.org/#{full}", minted_at: doi.minted_at,
            xml: Labimotion::BuildTemplateDoiXml.new(record, doi).call }
        end
      end
    end
    # rubocop:enable Metrics/BlockLength

    namespace :labimotion_template_browse do
      route_param :type, type: String, values: KLASS_TYPES do
        desc 'Released versions (revisions) of one template, each with properties_release'
        params do
          requires :identifier, type: String, desc: 'template identifier or uuid'
        end
        get :versions do
          model = KLASS_BY_TYPE[params[:type]]
          error!('unknown template type', 404) unless model

          record = find_template(model, params[:identifier])
          error!('template not found', 404) unless record

          {
            template: template_summary(record, params[:type]),
            versions: released_versions(record, params[:type]),
            dois: released_dois(record),
            publication: template_publication(record)
          }
        end
      end
    end
  end
end
