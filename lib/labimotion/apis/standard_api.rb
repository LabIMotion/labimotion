# frozen_string_literal: true

require 'labimotion/version'
require 'labimotion/libs/export_element'

module Labimotion
  # Generic Element API
  class StandardAPI < Grape::API
    resource :standards do
      namespace :create_std_layer do
        desc 'create standard layer'
        params do
          use :create_std_layer_params
        end
        post do
          authenticate_admin!('standard_layers')
          create_std_layer(current_user, params)
          status 201
        rescue ActiveRecord::RecordInvalid => e
          { error: e.message }
        end
      end
    end
  end
end
