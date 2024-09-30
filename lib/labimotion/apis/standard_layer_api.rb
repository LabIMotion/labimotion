# frozen_string_literal: true

require 'labimotion/version'

module Labimotion
  # Generic Element API
  class StandardLayerAPI < Grape::API
    include Grape::Kaminari
    helpers Labimotion::ParamHelpers
    helpers Labimotion::GenericHelpers

    resource :layers do
      namespace :get_all_layers do
        desc 'get all standard layers for designer'
        get do
          list = Labimotion::StdLayer.all.sort_by { |e| e.name }
          return { mc: 'ss00', data: list }
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          { mc: 'se00', msg: e.message, data: [] }
        end
      end

      namespace :get_standard_layer do
        desc 'get standard layer by id'
        route_param :id do
          get do
            authenticate_admin!('standard_layers')
            entity = Labimotion::StdLayer.find(params[:id])
            return { mc: 'ss00', data: entity }
          rescue StandardError => e
            Labimotion.log_exception(e, current_user)
            { mc: 'se00', msg: e.message, data: {} }
          end
        end
      end

      namespace :save_standard_layer do
        desc 'create Generic Element Klass'
        params do
          use :std_layer_save
        end
        before do
          authenticate_admin!('standard_layers')
          cur_layer = Labimotion::StdLayer.find_by(name: params[:key])
          error!('Error! duplicate name', 409) if cur_layer.present?
        end
        post do
          attributes = {
            name: params[:key],
            label: params[:label],
            description: params[:description],
            identifier: SecureRandom.uuid,
            created_by: current_user.id,
            properties: declared(params, include_missing: false)
          }
          layer = Labimotion::StdLayer.new(attributes)
          layer.save!
          { mc: 'ss00', data: layer }
        rescue ActiveRecord::RecordInvalid => e
          Labimotion.log_exception(e, current_user)
          { mc: 'se00', msg: e.message, data: {} }
        end
      end

      namespace :delete_standard_layer do
        desc 'delete standard layer by id'
        params do
          requires :id, type: Integer, desc: 'Standard layer id'
        end
        route_param :id do
          before do
            authenticate_admin!('standard_layers')
          end
          delete do
            entity = Labimotion::StdLayer.find(params[:id])
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
