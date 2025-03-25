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
          list = klass_list(true, false)
          present list.sort_by(&:place), with: Labimotion::DatasetKlassEntity, root: 'klass'
        end
      end

      namespace :list_klass do
        desc 'list Generic Dataset Klass'
        params do
          optional :is_active, type: Boolean, desc: 'Active or Inactive Dataset'
          optional :displayed_in_list, type: Boolean, desc: 'Display in list format', default: true
        end
        get do
          list = klass_list(params[:is_active], params[:displayed_in_list])
          serialized_data = Labimotion::DatasetKlassEntity.represent(list,
                                                                     displayed_in_list: params[:displayed_in_list])
          { mc: 'ss00', data: serialized_data }
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          { mc: 'se00', msg: e.message, data: [] }
        end
      end

      # Deprecated: This namespace is no longer used, but kept for backward compatibility.
      # It is replaced by `list_klass`.
      namespace :list_dataset_klass do
        desc 'list Generic Dataset Klass'
        params do
          optional :is_active, type: Boolean, desc: 'Active or Inactive Dataset'
        end
        get do
          list = klass_list(params[:is_active], false)
          present list, with: Labimotion::DatasetKlassEntity, root: 'klass', displayed_in_list: false
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

      namespace :find_template do
        desc 'Find best matching template for given OLS term ID'
        params do
          requires :ols_term_id, type: String, desc: 'OLS Term ID (e.g., CHMO:0000470)'
        end
        get do
          result = find_best_match_template(params[:ols_term_id])
          result
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          raise e
        end
      end
    end
  end
end
