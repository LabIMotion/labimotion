# frozen_string_literal: true

require 'labimotion/version'
require 'labimotion/libs/export_element'

module Labimotion
  # Generic Element API
  class GenericKlassAPI < Grape::API
    
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
          filename = URI.escape("LabIMotion_#{params[:klass]}_#{entity.label}-#{Time.new.strftime("%Y%m%d%H%M%S")}.json")
          # header['Content-Disposition'] = "attachment; filename=abc.docx"
          header('Content-Disposition', "attachment; filename=\"#{filename}\"")
          "Labimotion::#{params[:klass]}Entity".constantize.represent(entity)
          # klass.as_json
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          {}
        end
      end      
    end
  end
end