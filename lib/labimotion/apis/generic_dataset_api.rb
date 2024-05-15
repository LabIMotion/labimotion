# frozen_string_literal: true

module Labimotion
  ## Generic Dataset API
  class GenericDatasetAPI < Grape::API
    include Grape::Kaminari
    helpers Labimotion::GenericHelpers
    helpers Labimotion::DatasetHelpers

    resource :generic_dataset do
      namespace :klasses do
        desc 'get dataset klasses'
        get do
          list = klass_list(true)
          present list.sort_by(&:place), with: Labimotion::DatasetKlassEntity, root: 'klass'
        end
      end

      namespace :list_dataset_klass do
        desc 'list Generic Dataset Klass'
        params do
          optional :is_active, type: Boolean, desc: 'Active or Inactive Dataset'
        end
        get do
          list = klass_list(params[:is_active])
          present list, with: Labimotion::DatasetKlassEntity, root: 'klass'
        end
      end

      namespace :fetch_repo do
        desc 'fetch Generic Dataset Klass from Chemotion Repository'
        get do
          fetch_repo('DatasetKlass', current_user)
        end
      end

      namespace :create_repo_klass do
        desc 'create Generic Dataset Klass'
        params do
          requires :identifier, type: String, desc: 'Identifier'
        end
        post do
          msg = create_repo_klass(params, current_user, request.headers['Origin'])
          klass = Labimotion::DatasetKlassEntity.represent(Labimotion::DatasetKlass.all)
          { status: msg[:status], message: msg[:message], klass: klass }
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          { error: e.message }
        end
      end
    end
  end
end
