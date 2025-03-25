# frozen_string_literal: true

require 'cgi'
require 'labimotion/version'
require 'labimotion/libs/export_element'

module Labimotion
  # Generic Element API
  class GenericKlassAPI < Grape::API
    helpers Labimotion::GenericHelpers

    resource :generic_klass do
      namespace :download_klass do
        desc 'export klass'
        params do
          requires :id, type: Integer, desc: 'element id'
          requires :klass, type: String, desc: 'Klass', values: %w[ElementKlass SegmentKlass DatasetKlass]
        end
        get do
          entity = "Labimotion::#{params[:klass]}".constantize.find_by(id: params[:id])
          entity.update_columns(identifier: SecureRandom.uuid) if entity&.identifier.nil?
          env['api.format'] = :binary
          content_type('application/json')
          filename = CGI.escape("LabIMotion_#{params[:klass]}_#{entity.label}-#{Time.new.strftime("%Y%m%d%H%M%S")}.json")
          # header['Content-Disposition'] = "attachment; filename=abc.docx"
          header('Content-Disposition', "attachment; filename=\"#{filename}\"")
          "Labimotion::#{params[:klass]}Entity".constantize.represent(entity)
          # klass.as_json
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          {}
        end
      end

      namespace :de_activate do
        desc 'activate or deactivate Generic Klass'
        params do
          requires :klass, type: String, desc: 'Klass', values: %w[ElementKlass SegmentKlass DatasetKlass]
          requires :id, type: Integer, desc: 'Klass ID'
          requires :is_active, type: Boolean, desc: 'Active or Inactive Klass'
        end
        after_validation do
          authenticate_admin!(params[:klass].gsub(/(Klass)/, 's').downcase)
          fetch_klass(params[:klass], params[:id])
        end
        post do
          updated_klass = deactivate_klass(params)
          entity_class = "Labimotion::#{params[:klass]}Entity".constantize
          serialized_data = entity_class.represent(updated_klass)
          { mc: 'ss00', data: serialized_data }
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          { mc: 'se00', msg: e.message, data: {} }
        end
      end

      namespace :fetch do
        desc 'fetch Generic Klass by id'
        params do
          requires :id, type: Integer, desc: 'Klass ID'
          requires :klass, type: String, desc: 'Klass', values: %w[ElementKlass SegmentKlass DatasetKlass]
        end
        get do
          klass_obj = fetch_klass(params[:klass], params[:id])
          entity_class = "Labimotion::#{params[:klass]}Entity".constantize
          serialized_data = entity_class.represent(klass_obj)
          { mc: 'ss00', data: serialized_data }
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          { mc: 'se00', msg: e.message, data: {} }
        end
      end
    end
  end
end
