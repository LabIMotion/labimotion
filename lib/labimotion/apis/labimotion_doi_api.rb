# frozen_string_literal: true

module Labimotion
  # DOI lifecycle (reserve + release) and publication metadata for
  # LabIMotion templates: ElementKlass / SegmentKlass / DatasetKlass.
  class LabimotionDoiAPI < Grape::API
    # rubocop:disable Metrics/BlockLength
    # Grape route and helper DSL blocks are necessarily large.
    KLASS_TYPES = Labimotion::TemplateDoiHelpers::KLASS_BY_TYPE.keys.freeze

    helpers do
      def resolve_klass!(type, id)
        model = Labimotion::TemplateDoiHelpers::KLASS_BY_TYPE[type]
        error!('unknown template type', 404) unless model

        record = model.find_by(id: id)
        error!('template not found', 404) unless record

        record
      end

      def render_template_doi(record)
        type = Labimotion::TemplateDoiHelpers.klass_type_for(record)
        dois = ::Doi.labimotion_dois(record)
        # `doi` is the current (most recently reserved) DOI; `released_doi` is the
        # latest released (minted) one. They differ once a new version has been
        # reserved on top of a released one, so the modal can show both at once.
        doi = dois.last
        released_doi = dois.reverse.find(&:minted)
        Labimotion::LabimotionTemplateDoiEntity.represent(
          type: type,
          klass_id: record.id,
          doi: doi,
          released_doi_version: released_doi && ::Doi.labimotion_doi_version(released_doi),
          publication: (record.properties_template || {})['publication'],
          released_at: record.released_at,
          released_by: record.released_by,
          new_version_available: Labimotion::TemplateDoiHelpers.new_version_available?(record),
          next_doi_version: ::Doi.labimotion_version_segment(record),
          template_url: Labimotion::TemplateDoiHelpers.template_url(record)
        )
      end

      # Public, read-only view of one released DOI version.
      def released_doi_version(doi)
        full = doi.full_doi
        {
          doi: full,
          doi_url: "https://dx.doi.org/#{full}",
          version: ::Doi.labimotion_doi_version(doi),
          minted_at: doi.minted_at
        }
      end

      # Public payload for a template that has at least one released DOI: the
      # latest released DOI promoted to the top level, plus its publication
      # metadata, hub deep-link and every released version. `record_id` matches
      # the hub grid's row id (identifier || uuid) so the frontend can merge it.
      def released_template_doi(record, dois)
        versions = dois.sort_by(&:id).map { |doi| released_doi_version(doi) }
        publication = (record.properties_template || {})['publication']
        publication = publication.is_a?(Hash) ? publication.slice('title', 'description', 'authors', 'license') : {}
        versions.last.merge(
          record_id: record.try(:identifier).presence || record.try(:uuid).presence || record.id,
          identifier: record.try(:identifier),
          uuid: record.try(:uuid),
          label: record.try(:label),
          template_version: record.try(:version),
          next_doi_version: ::Doi.labimotion_version_segment(record),
          template_url: Labimotion::TemplateDoiHelpers.template_url(record),
          publication: publication,
          versions: versions
        )
      end
    end

    namespace :labimotion_doi do
      # Public, anonymous read-only DOI info for the LabIMotion Template Hub.
      # Whitelisted in RepoAPI::PUBLIC_URLS so it bypasses authenticate!; only
      # released (minted) DOIs and their public publication metadata are exposed.
      namespace :public do
        route_param :type, type: String, values: KLASS_TYPES do
          desc 'Released DOIs + publication metadata for every released template of a type'
          get :released do
            model = Labimotion::TemplateDoiHelpers::KLASS_BY_TYPE[params[:type]]
            grouped = ::Doi.where(doiable_type: model.name).where.not(minted_at: nil)
                           .order(:id).group_by(&:doiable_id)
            records = model.where(id: grouped.keys).index_by(&:id)
            released = grouped.filter_map do |klass_id, dois|
              record = records[klass_id]
              record && released_template_doi(record, dois)
            end
            { released_dois: released }
          end
        end
      end

      route_param :type, type: String, values: KLASS_TYPES do
        desc "DOI state (reserved / released) per template of a type, for the designer grid's DOI icon"
        get :states do
          model = Labimotion::TemplateDoiHelpers::KLASS_BY_TYPE[params[:type]]
          grouped = ::Doi.where(doiable_type: model.name).order(:id).group_by(&:doiable_id)
          states = grouped.transform_values do |list|
            released = list.last.minted == true
            { reserved: !released, released: released }
          end
          { states: states }
        end

        route_param :id, type: Integer do
          desc 'Returns the current DOI/publication state for a template'
          get do
            record = resolve_klass!(params[:type], params[:id])
            render_template_doi(record)
          end

          desc "Returns the DataCite metadata XML for every one of the template's DOI versions"
          get :metadata_xml do
            record = resolve_klass!(params[:type], params[:id])
            dois = ::Doi.labimotion_dois(record)
            error!('no DOI reserved', 404) if dois.empty?

            versions = dois.map do |doi|
              {
                version: ::Doi.labimotion_doi_version(doi),
                full_doi: doi.full_doi,
                minted: doi.minted == true,
                xml: Labimotion::BuildTemplateDoiXml.new(record, doi, current_user).call
              }
            end
            { versions: versions }
          end

          desc 'Updates the publication metadata of a template'
          params do
            requires :publication, type: Hash
          end
          put :publication_metadata do
            record = resolve_klass!(params[:type], params[:id])
            uc = Labimotion::UpdateTemplatePublicationMetadata.new(
              record, current_user, params[:publication]
            ).call
            error!(uc.error, 422) unless uc.success?

            render_template_doi(record.reload)
          end

          desc 'Reserves a DataCite DOI for a template'
          post :reserve_doi do
            record = resolve_klass!(params[:type], params[:id])
            uc = Labimotion::ReserveTemplateDoi.new(record, current_user).call
            error!(uc.error, 422) unless uc.success?

            render_template_doi(record.reload)
          end

          desc 'Releases (mints) the reserved DOI for a template'
          post :release_doi do
            record = resolve_klass!(params[:type], params[:id])
            uc = Labimotion::ReleaseTemplateDoi.new(record, current_user).call
            error!(uc.error, 422) unless uc.success?

            render_template_doi(record.reload)
          end
        end
      end
    end
    # rubocop:enable Metrics/BlockLength
  end
end
