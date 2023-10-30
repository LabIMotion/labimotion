# frozen_string_literal: true
require 'grape'
module Labimotion
    ## DatasetHelpers
  module DatasetHelpers
    extend Grape::API::Helpers

    def klass_list(is_active)
      if is_active == true
        Labimotion::DatasetKlass.where(is_active: true).order('place') || []
      else
        Labimotion::DatasetKlass.all.order('place') || []
      end
    end

    def create_repo_klass(params, current_user, origin)
      response = Labimotion::TemplateHub.fetch_identifier('DatasetKlass', params[:identifier], origin)
      attributes = response.slice('ols_term_id', 'label', 'desc', 'uuid', 'identifier', 'properties_release', 'version') # .except(:id, :is_active, :place, :created_by, :created_at, :updated_at)
      attributes['properties_release']['identifier'] = attributes['identifier']
      attributes['properties_template'] = attributes['properties_release']
      attributes['place'] = ((Labimotion::DatasetKlass.all.length * 10) || 0) + 10
      attributes['is_active'] = false
      attributes['updated_by'] = current_user.id
      attributes['sync_by'] = current_user.id
      attributes['sync_time'] = DateTime.now
      dataset_klass = Labimotion::DatasetKlass.find_by(ols_term_id: attributes['ols_term_id'])
      if dataset_klass.present?
        if dataset_klass['uuid'] == attributes['uuid'] && dataset_klass['version'] == attributes['version']
          { status: 'success', message: "This dataset: #{attributes['label']} has the latest version!" }
        else
          ds = Labimotion::DatasetKlass.find_by(ols_term_id: attributes['ols_term_id'])
          ds.update!(attributes)
          ds.create_klasses_revision(current_user)
          { status: 'success', message: "This dataset: [#{attributes['label']}] has been upgraded to the version: #{attributes['version']}!" }
        end
      else
        attributes['created_by'] = current_user.id
        ds = Labimotion::DatasetKlass.create!(attributes)
        ds.create_klasses_revision(current_user)
        { status: 'success', message: "The dataset: #{attributes['label']} has been created using version: #{attributes['version']}!" }
      end
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      # { error: e.message }
      raise e
    end
  end
end
