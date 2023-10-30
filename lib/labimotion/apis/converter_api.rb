# frozen_string_literal: true

module Labimotion
  class ConverterAPI < Grape::API
    helpers do
    end
    resource :converter do
      resource :profiles do
        before do
          @conf = Rails.configuration.try(:converter).try(:url)
          @profile = Rails.configuration.try(:converter).try(:profile)
          error!(406) unless @conf && @profile
        end
        desc 'fetch profiles'
        get do
          profiles = Labimotion::Converter.fetch_profiles
          { profiles: profiles, client: @profile }
        end
        desc 'create profile'
        post do
          Labimotion::Converter.create_profile(params)
        end
        desc 'update profile'
        route_param :id do
          put do
            Labimotion::Converter.update_profile(params)
          end
        end
        desc 'delete profile'
        route_param :id do
          delete do
            id = params[:id]
            Labimotion::Converter.delete_profile(id)
          end
        end
      end

      resource :options do
        before do
          error!(401) unless current_user.profile&.data['converter_admin'] == true
          @conf = Rails.configuration.try(:converter).try(:url)
          @profile = Rails.configuration.try(:converter).try(:profile)
          error!(406) unless @conf && @profile
        end
        desc 'fetch options'
        get do
          options = Labimotion::Converter.fetch_options
          { options: options, client: @profile }
        end
      end

      resource :tables do
        before do
          error!(401) unless current_user.profile&.data['converter_admin'] == true
          @conf = Rails.configuration.try(:converter).try(:url)
          @profile = Rails.configuration.try(:converter).try(:profile)
          error!(406) unless @conf && @profile
        end
        desc 'create tables'
        post do
          res = Labimotion::Converter.create_tables(params[:file][0]['tempfile']) unless params[:file].empty?
          res['metadata']['file_name'] = params[:file][0]['filename']
          res
        end
      end
    end
  end
end
