# frozen_string_literal: true
require 'grape'
require 'labimotion/models/segment_klass'
require 'labimotion/utils/utils'

module Labimotion
  ## ElementHelpers
  module SegmentHelpers
    extend Grape::API::Helpers

    def klass_list(el_klass, is_active=false)
      scope = Labimotion::SegmentKlass.all
      scope = scope.where(is_active: is_active) if is_active.present? && is_active == true
      scope = scope.joins(:element_klass).where(klass_element: params[:element], is_active: true).preload(:element_klass) if el_klass.present?
      scope.order('place') || []
    end

    def create_segment_klass(current_user, params)
      place = params[:place]
      begin
        place = place.to_i if place.present? && place.to_i == place.to_f
      rescue StandardError
        place = 100
      end

      uuid = SecureRandom.uuid
      template = { uuid: uuid, layers: {}, select_options: {} }
      attributes = declared(params, include_missing: false)
      attributes[:properties_template]['uuid'] = uuid if attributes[:properties_template].present?
      template = (attributes[:properties_template].presence || template)
      template['pkg'] = Labimotion::Utils.pkg(template['pkg'])
      template['klass'] = 'SegmentKlass'
      attributes.merge!(properties_template: template, element_klass: @klass, created_by: current_user.id,
                        place: place)
      attributes[:is_active] = false
      attributes[:uuid] = uuid
      attributes[:released_at] = DateTime.now
      attributes[:properties_release] = attributes[:properties_template]
      klass = Labimotion::SegmentKlass.create!(attributes)
      klass.reload
      klass.create_klasses_revision(current_user)
      klass
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      raise e
    end

    def update_segment_klass(current_user, params)
      segment = fetch_klass('SegmentKlass', params[:id])
      place = params[:place]
      begin
        place = place.to_i if place.present? && place.to_i == place.to_f
      rescue StandardError
        place = 100
      end
      attributes = declared(params, include_missing: false)
      attributes.delete(:id)
      attributes[:place] = place
      segment&.update!(attributes)
      segment
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      raise e
    end

    def validate_klass(attributes, attr_klass)
      element_klass = Labimotion::ElementKlass.find_by(identifier: attr_klass['identifier']) if attr_klass.dig('identifier').present?
      element_klass = Labimotion::ElementKlass.find_by(name: attr_klass['name'], is_generic: false) if element_klass.nil?
      return { status: 'error', message: "The element [#{attr_klass['name']}] does not exist in this instance" } if element_klass.nil?

      # el_attributes = response['element_klass'].slice('name', 'label', 'desc', 'uuid', 'identifier', 'icon_name', 'klass_prefix', 'is_generic', 'released_at')
      # el_attributes['properties_template'] = response['element_klass']['properties_release']
      # Labimotion::ElementKlass.create!(el_attributes)
      attributes['element_klass_id'] = element_klass.id
      segment_klass = Labimotion::SegmentKlass.find_by(identifier: attributes['identifier'])
      if segment_klass.present?
        if segment_klass['uuid'] == attributes['uuid'] && segment_klass['version'] == attributes['version']
          return { status: 'success', message: "This segment: #{attributes['label']} has the latest version!" }
        else
          segment_klass.update!(attributes)
          segment_klass.create_klasses_revision(current_user)
          return { status: 'success', message: "This segment: [#{attributes['label']}] has been upgraded to the version: #{attributes['version']}!" }
        end
      else
        exist_klass = Labimotion::SegmentKlass.find_by(label: attributes['label'], element_klass_id: element_klass.id)
        if exist_klass.present?
          return { status: 'error', message: "The segment [#{attributes['label']}] is already in use." }
        else
          attributes['created_by'] = current_user.id
          segment_klass = Labimotion::SegmentKlass.create!(attributes)
          segment_klass.create_klasses_revision(current_user)
          return { status: 'success', message: "The segment: #{attributes['label']} has been created using version: #{attributes['version']}!" }
        end
      end
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      return { status: 'error', message: e.message }
    end

    def create_repo_klass(params, current_user, origin)
      response = Labimotion::TemplateHub.fetch_identifier('SegmentKlass', params[:identifier], origin)
      attributes = response.slice('label', 'desc', 'uuid', 'identifier', 'released_at', 'properties_release', 'version')
      attributes['properties_release']['identifier'] = attributes['identifier']
      attributes['properties_template'] = attributes['properties_release']
      attributes['place'] = ((Labimotion::SegmentKlass.all.length * 10) || 0) + 10
      attributes['is_active'] = false
      attributes['updated_by'] = current_user.id
      attributes['sync_by'] = current_user.id
      attributes['sync_time'] = DateTime.now
      attr_klass = response['element_klass']    ## response.dig('element_klass', {})        # response['element_klass']
      validate_klass(attributes, attr_klass)

    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      raise e
    end
  end
end
