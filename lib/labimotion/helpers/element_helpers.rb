# frozen_string_literal: true

require 'grape'
require 'labimotion/utils/utils'
# require 'labimotion/models/element_klass'
module Labimotion
  ## ElementHelpers
  module ElementHelpers
    extend Grape::API::Helpers

    def klass_list(is_generic_only)
      if is_generic_only == true
        Labimotion::ElementKlass.where(is_active: true, is_generic: true).order('place') || []
      else
        Labimotion::ElementKlass.where(is_active: true).order('place') || []
      end
    end

    def create_element_klass(current_user, params)
      uuid = SecureRandom.uuid
      template = { uuid: uuid, layers: {}, select_options: {} }
      attributes = declared(params, include_missing: false)
      attributes[:properties_template] = template if attributes[:properties_template].nil?
      attributes[:properties_template]['uuid'] = uuid
      attributes[:properties_template]['pkg'] = Labimotion::Utils.pkg(attributes[:properties_template]['pkg'])
      attributes[:properties_template]['klass'] = 'ElementKlass'
      attributes[:is_active] = false
      attributes[:uuid] = uuid
      attributes[:released_at] = DateTime.now
      attributes[:properties_release] = attributes[:properties_template]
      attributes[:created_by] = current_user.id

      new_klass = Labimotion::ElementKlass.create!(attributes)
      new_klass.reload
      new_klass.create_klasses_revision(current_user)
      klass_names_file = Rails.root.join('app/packs/klasses.json')
      klasses = Labimotion::ElementKlass.where(is_active: true)&.pluck(:name) || []
      File.write(klass_names_file, klasses)
      klasses
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      raise e
    end

    def update_element_klass(current_user, params)
      place = params[:place] || 100
      begin
        place = place.to_i if place.present? && place.to_i == place.to_f
      rescue StandardError
        place = 100
      end
      klass = Labimotion::ElementKlass.find(params[:id])
      klass.label = params[:label] if params[:label].present?
      klass.klass_prefix = params[:klass_prefix] if params[:klass_prefix].present?
      klass.icon_name = params[:icon_name] if params[:icon_name].present?
      klass.desc = params[:desc] if params[:desc].present?
      klass.place = place
      klass.save!
      klass
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      raise e
    end

    def create_element(current_user, params)
      klass = params[:element_klass] || {}
      uuid = SecureRandom.uuid
      params[:properties]['uuid'] = uuid
      params[:properties]['klass_uuid'] = klass[:uuid]
      params[:properties]['pkg'] = Labimotion::Utils.pkg(params[:properties]['pkg'])
      params[:properties]['klass'] = 'Element'
      params[:properties]['identifier'] = klass[:identifier]
      properties = params[:properties]
      properties.delete('flow') unless properties['flow'].nil?
      properties.delete('flowObject') unless properties['flowObject'].nil?
      properties.delete('select_options') unless properties['select_options'].nil?
      attributes = {
        name: params[:name],
        element_klass_id: klass[:id],
        uuid: uuid,
        klass_uuid: klass[:uuid],
        properties: properties,
        properties_release: params[:properties_release],
        created_by: current_user.id,
      }
      element = Labimotion::Element.new(attributes)

      if params[:collection_id]
        collection = current_user.collections.find(params[:collection_id])
        element.collections << collection
      end
      all_coll = Collection.get_all_collection_for_user(current_user.id)
      element.collections << all_coll
      element.save!
      element.properties = update_sample_association(params[:properties], current_user, element)
      element.container = update_datamodel(params[:container], current_user)
      element.save!
      element.save_segments(segments: params[:segments], current_user_id: current_user.id)
      element
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      raise e
    end

    def update_element_by_id(current_user, params)
      element = Labimotion::Element.find(params[:id])
      update_datamodel(params[:container], current_user)
      properties = update_sample_association(params[:properties], current_user, element)
      params.delete(:container)
      params.delete(:properties)
      attributes = declared(params.except(:segments), include_missing: false)
      properties['pkg'] = Labimotion::Utils.pkg(properties['pkg'])
      if element.klass_uuid != properties['klass_uuid'] || element.properties != properties || element.name != params[:name]
        properties['klass'] = 'Element'
        uuid = SecureRandom.uuid
        properties['uuid'] = uuid

        properties.delete('flow') unless properties['flow'].nil?
        properties.delete('flowObject') unless properties['flowObject'].nil?
        properties.delete('select_options') unless properties['select_options'].nil?

        attributes['properties'] = properties
        attributes['properties']['uuid'] = uuid
        attributes['uuid'] = uuid
        attributes['klass_uuid'] = properties['klass_uuid']

        element.update(attributes)
      end
      element.save_segments(segments: params[:segments], current_user_id: current_user.id)
      element
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      raise e
    end

    def upload_generics_files(current_user, params)
      attach_ary = []
      att_ary = create_uploads(
        'Element',
        params[:att_id],
        params[:elfiles],
        params[:elInfo],
        current_user.id,
      ) if params[:elfiles].present? && params[:elInfo].present?

      (attach_ary << att_ary).flatten! unless att_ary&.empty?

      att_ary = create_uploads(
        'Segment',
        params[:att_id],
        params[:sefiles],
        params[:seInfo],
        current_user.id
      ) if params[:sefiles].present? && params[:seInfo].present?

      (attach_ary << att_ary).flatten! unless att_ary&.empty?

      if params[:attfiles].present? || params[:delfiles].present? then
        att_ary = create_attachments(
          params[:attfiles],
          params[:delfiles],
          "Labimotion::#{params[:att_type]}",
          params[:att_id],
          params[:attfilesIdentifier],
          current_user.id
        )
      end
      (attach_ary << att_ary).flatten! unless att_ary&.empty?

      if Labimotion::IS_RAILS5 == true
        TransferThumbnailToPublicJob.set(queue: "transfer_thumbnail_to_public_#{current_user.id}").perform_now(attach_ary) unless attach_ary.empty?
        TransferFileFromTmpJob.set(queue: "transfer_file_from_tmp_#{current_user.id}").perform_now(attach_ary) unless attach_ary.empty?
      end
      true
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      false
    end

    def element_revisions(params)
      klass = Labimotion::Element.find(params[:id])
      list = klass.elements_revisions unless klass.nil?
      list&.sort_by(&:created_at)&.reverse&.first(10)
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      raise e
    end

    def list_user_elements(scope, params)
      from = params[:from_date]
      to = params[:to_date]
      by_created_at = params[:filter_created_at] || false

      if params[:sort_column]&.include?('.')
        layer, field = params[:sort_column].split('.')

        element_klass = Labimotion::ElementKlass.find_by(name: params[:el_type])
        allowed_fields = element_klass.properties_release.dig('layers', layer, 'fields')&.pluck('field') || []

        if field.in?(allowed_fields)
          query = ActiveRecord::Base.sanitize_sql(
            [
              "LEFT JOIN LATERAL(
                SELECT field->'value' AS value
                FROM jsonb_array_elements(properties->'layers'->:layer->'fields') a(field)
                WHERE field->>'field' = :field
              ) a ON true",
              { layer: layer, field: field },
            ],
          )
          scope = scope.joins(query).order('value ASC NULLS FIRST')
        else
          scope = scope.order(updated_at: :desc)
        end
      else
        scope = scope.order(updated_at: :desc)
      end

      scope = scope.created_time_from(Time.at(from)) if from && by_created_at
      scope = scope.created_time_to(Time.at(to) + 1.day) if to && by_created_at
      scope = scope.updated_time_from(Time.at(from)) if from && !by_created_at
      scope = scope.updated_time_to(Time.at(to) + 1.day) if to && !by_created_at
      scope
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      raise e
    end

    def list_serialized_elements(params, current_user)
      collection_id =
      if params[:collection_id]
        Collection
          .belongs_to_or_shared_by(current_user.id, current_user.group_ids)
          .find_by(id: params[:collection_id])&.id
      elsif params[:sync_collection_id]
        current_user
          .all_sync_in_collections_users
          .find_by(id: params[:sync_collection_id])&.collection&.id
      end

      scope =
      if collection_id
        Labimotion::Element
          .joins(:element_klass, :collections_elements)
          .where(
            element_klasses: { name: params[:el_type] },
            collections_elements: { collection_id: collection_id },
          ).includes(:tag, collections: :sync_collections_users)
      else
        Labimotion::Element.none
      end

      ## TO DO: refactor labimotion
      from = params[:from_date]
      to = params[:to_date]
      by_created_at = params[:filter_created_at] || false
      if params[:sort_column]&.include?('.')
        layer, field = params[:sort_column].split('.')

        element_klass = Labimotion::ElementKlass.find_by(name: params[:el_type])
        allowed_fields = element_klass.properties_release.dig('layers', layer, 'fields')&.pluck('field') || []

        if field.in?(allowed_fields)
          query = ActiveRecord::Base.sanitize_sql(
            [
              "LEFT JOIN LATERAL(
                SELECT field->'value' AS value
                FROM jsonb_array_elements(properties->'layers'->:layer->'fields') a(field)
                WHERE field->>'field' = :field
              ) a ON true",
              { layer: layer, field: field },
            ],
          )
          scope = scope.joins(query).order('value ASC NULLS FIRST')
        else
          scope = scope.order(updated_at: :desc)
        end
      else
        scope = scope.order(updated_at: :desc)
      end

      scope = scope.elements_created_time_from(Time.at(from)) if from && by_created_at
      scope = scope.elements_created_time_to(Time.at(to) + 1.day) if to && by_created_at
      scope = scope.elements_updated_time_from(Time.at(from)) if from && !by_created_at
      scope = scope.elements_updated_time_to(Time.at(to) + 1.day) if to && !by_created_at
      scope
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      raise e
    end

    def create_repo_klass(params, current_user, origin)
      response = Labimotion::TemplateHub.fetch_identifier('ElementKlass', params[:identifier], origin)
      attributes = response.slice('name', 'label', 'desc', 'icon_name', 'uuid', 'klass_prefix', 'is_generic', 'identifier', 'properties_release', 'version')
      attributes['properties_release']['identifier'] = attributes['identifier']
      attributes['properties_template'] = attributes['properties_release']
      attributes['place'] = ((Labimotion::DatasetKlass.all.length * 10) || 0) + 10
      attributes['is_active'] = false
      attributes['updated_by'] = current_user.id
      attributes['sync_by'] = current_user.id
      attributes['sync_time'] = DateTime.now

      element_klass = Labimotion::ElementKlass.find_by(identifier: attributes['identifier'])
      if element_klass.present?
        if element_klass['uuid'] == attributes['uuid'] && element_klass['version'] == attributes['version']
          { status: 'success', message: "This element: #{attributes['name']} has the latest version!" }
        else
          element_klass.update!(attributes)
          element_klass.create_klasses_revision(current_user)
          { status: 'success', message: "This element: [#{attributes['name']}] has been upgraded to the version: #{attributes['version']}!" }
        end
      else
        exist_klass = Labimotion::ElementKlass.find_by(name: attributes['name'])
        if exist_klass.present?
          { status: 'error', message: "The name [#{attributes['name']}] is already in use." }
        else
          attributes['created_by'] = current_user.id
          element_klass = Labimotion::ElementKlass.create!(attributes)
          element_klass.create_klasses_revision(current_user)
          { status: 'success', message: "The element: #{attributes['name']} has been created using version: #{attributes['version']}!" }
        end
      end
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      # { error: e.message }
      raise e
    end

    def attach_thumbnail(_attachments)
      attachments = _attachments&.map do |attachment|
        _att = Entities::AttachmentEntity.represent(attachment, serializable: true)
        _att[:thumbnail] = attachment.thumb ? Base64.encode64(attachment.read_thumbnail) : nil
        _att
      end
      attachments
    end

  end
end
