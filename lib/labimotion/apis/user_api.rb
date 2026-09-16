# frozen_string_literal: true

require 'labimotion/version'

module Labimotion
  # User API
  class UserAPI < Grape::API
    helpers Labimotion::ParamHelpers
    helpers Labimotion::GenericHelpers

    resource :limo do
      resource :users do
        namespace :list do
          desc 'List users by keyword'
          params do
            requires :name, type: String, desc: 'Keyword'
            optional :limit, type: Integer, default: 5, desc: 'Limit (max 10)'
            optional :type, type: String, default: 'Person', desc: 'User type'
          end
          get do
            error!('401 Unauthorized', 401) unless current_user
            return { mc: 'ss00', msg: 'Entered name too short', data: [] } if params[:name].to_s.length < 3

            query = 'first_name ILIKE :q OR last_name ILIKE :q OR name ILIKE :q OR name_abbreviation ILIKE :q'
            users = User.where(query, q: "%#{params[:name]}%")
                        .where(type: params[:type])
                        .limit([params[:limit].to_i, 10].min)
            data = Labimotion::UserEntity.represent(users)
            { mc: 'ss00', data: data }
          rescue StandardError => e
            Labimotion.log_exception(e, current_user)
            { mc: 'se00', msg: e.message, data: [] }
          end
        end

        desc 'Get user info by id'
        params do
          requires :id, type: Integer, desc: 'User id'
        end
        route_param :id do
          get do
            error!('401 Unauthorized', 401) unless current_user
            user = User.find(params[:id])
            data = Labimotion::UserEntity.represent(user)
            { mc: 'ss00', data: data }
          rescue ActiveRecord::RecordNotFound
            error!('404 Not Found', 404)
          rescue StandardError => e
            Labimotion.log_exception(e, current_user)
            { mc: 'se00', msg: e.message, data: {} }
          end
        end
      end
    end
  end
end
