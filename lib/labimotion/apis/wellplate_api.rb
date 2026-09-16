# frozen_string_literal: true

module Labimotion
  # API for wellplates linked to a generic element
  class WellplateAPI < Grape::API
    resource :wellplates do
      namespace :by_generic_element do
        desc 'Get wellplates for a generic element'
        params do
          requires :element_id, type: Integer, desc: 'Generic element id'
        end
        route_param :element_id do
          get do
            element = Labimotion::Element.find_by(id: params[:element_id])
            error!('404 Not Found', 404) unless element
            error!('401 Unauthorized', 401) unless ElementPolicy.new(current_user, element).read?

            wellplate_ids = Labimotion::ElementsWellplate.where(element_id: element.id).pluck(:wellplate_id)
            wellplates = Wellplate.where(id: wellplate_ids)
                                  .includes(:wells, wells: :sample)

            serialized_wellplates = wellplates.map do |wellplate|
              detail_levels = ElementDetailLevelCalculator.new(user: current_user, element: wellplate).detail_levels
              Entities::WellplateEntity.represent(wellplate, detail_levels: detail_levels)
            end

            { wellplates: serialized_wellplates }
          end

          desc 'Update wellplates for a generic element'
          params do
            requires :wellplate_ids, type: Array, desc: 'Wellplate IDs'
          end
          put do
            element = Labimotion::Element.find_by(id: params[:element_id])
            error!('404 Not Found', 404) unless element
            error!('401 Unauthorized', 401) unless ElementPolicy.new(current_user, element).update?

            ActiveRecord::Base.transaction do
              current_ids = Labimotion::ElementsWellplate.where(element_id: element.id).pluck(:wellplate_id)
              new_ids = params[:wellplate_ids] || []

              ids_to_remove = current_ids - new_ids
              if ids_to_remove.any?
                Labimotion::ElementsWellplate.where(element_id: element.id, wellplate_id: ids_to_remove).destroy_all
              end

              ids_to_add = new_ids - current_ids
              ids_to_add.each do |wellplate_id|
                Labimotion::ElementsWellplate.create!(element_id: element.id, wellplate_id: wellplate_id)
              end
            end

            { wellplate_ids: Labimotion::ElementsWellplate.where(element_id: element.id).pluck(:wellplate_id) }
          end
        end
      end
    end
  end
end
