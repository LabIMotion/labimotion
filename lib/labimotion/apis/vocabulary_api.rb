# frozen_string_literal: true

require 'labimotion/version'

module Labimotion
  # Generic Element API
  class VocabularyAPI < Grape::API
    include Grape::Kaminari
    helpers Labimotion::ParamHelpers
    helpers Labimotion::GenericHelpers

    resource :vocab do
      namespace :save_vocabulary do
        desc 'Save vocabularies'
        params do
          use :vocab_save
        end
        before do
          authenticate_admin!('vocabularies')
        rescue ActiveRecord::RecordNotFound
          error!('404 Not Found', 404)
        end
        post do
          attributes = {
            name: params[:name],
            label: params[:label],
            field_type: params[:field_type],
            opid: 8,
            term_id: params[:term_id],
            source: params[:source],
            source_id: params[:source_id],
            layer_id: params[:layer_id],
            field_id: params[:name],
            identifier: SecureRandom.uuid,
            created_by: current_user.id,
            properties: declared(params, include_missing: false),
          }
          voc = Labimotion::Vocabulary.new(attributes)
          voc.save!
          { mc: 'ss00', data: voc }
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          { mc: 'se00', msg: e.message, data: {} }
        end
      end

      namespace :get_all_vocabularies do
        desc 'get all standard layers for designer'
        get do
          authenticate_admin!('vocabularies')
          combined_data = Labimotion::VocabularyHandler.load_all_vocabularies
          return { mc: 'ss00', data: combined_data }
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          { mc: 'se00', msg: e.message, data: [] }
        end
      end

      namespace :field_klasses do
        desc 'get all field klasses for admin function'
        get do
          authenticate_admin!('vocabularies')
          vocabularies = Labimotion::VocabularyHandler.load_app_vocabularies
          merged_data = Labimotion::FieldKlassEntity.represent(vocabularies, serializable: true)
          merged_data
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          []
        end
      end

      namespace :delete_vocabulary do
        desc 'delete vocabulary by id'
        params do
          requires :id, type: Integer, desc: 'Vocabulary id'
        end
        route_param :id do
          before do
            authenticate_admin!('vocabularies')
          end
          delete do
            entity = Labimotion::Vocabulary.find(params[:id])
            entity.destroy
            return { mc: 'ss00', data: {} }
          rescue StandardError => e
            Labimotion.log_exception(e, current_user)
            { mc: 'se00', msg: e.message, data: [] }
          end
        end
      end
    end
  end
end
