# frozen_string_literal: true

require 'open-uri'
require 'labimotion/models/hub_log'

# Belong to Chemotion module
module Labimotion
  # API for Public data
  class LabimotionHubAPI < Grape::API
    include Grape::Kaminari

    namespace :labimotion_hub do
      namespace :list do
        desc "get active generic templates"
        params do
          requires :klass, type: String, desc: 'Klass', values: %w[ElementKlass SegmentKlass DatasetKlass]
          optional :with_props, type: Boolean, desc: 'With Properties', default: false
        end
        get do
          list = "Labimotion::#{params[:klass]}".constantize.where(is_active: true).where.not(released_at: nil)
          list = list.where(is_generic: true) if params[:klass] == 'ElementKlass'
          entities = Labimotion::GenericPublicEntity.represent(list, displayed: params[:with_props], root: 'list')
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          []
        end
      end
      namespace :fetch do
        desc "get active generic templates"
        params do
          requires :klass, type: String, desc: 'Klass', values: %w[ElementKlass SegmentKlass DatasetKlass]
          requires :origin, type: String, desc: 'origin'
          requires :identifier, type: String, desc: 'Identifier'
        end
        post do
          entity = "Labimotion::#{params[:klass]}".constantize.find_by(identifier: params[:identifier])
          Labimotion::HubLog.create(klass: entity, origin: params[:origin], uuid: entity.uuid, version: entity.version)
          "Labimotion::#{params[:klass]}Entity".constantize.represent(entity)
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          raise e
        end
      end

      namespace :element_klasses_name do
        desc "get klasses"
        params do
          optional :generic_only, type: Boolean, desc: "list generic element only"
        end
        get do
          list = Labimotion::ElementKlass.where(is_active: true) if params[:generic_only].present? && params[:generic_only] == true
          list = Labimotion::ElementKlass.where(is_active: true) unless params[:generic_only].present? && params[:generic_only] == true
          list.pluck(:name)
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          []
        end
      end

    end
  end
end
