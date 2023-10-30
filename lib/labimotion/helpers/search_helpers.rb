# frozen_string_literal: true
require 'grape'
# require 'labimotion/models/segment_klass'
module Labimotion
  ## ElementHelpers
  module SearchHelpers
    extend Grape::API::Helpers

    def serialization_elements(result, page, page_size, element_ids, params)
      # klasses = Labimotion::ElementKlass.where(is_active: true, is_generic: true)
      # klasses.each do |klass|
      #   element_ids_for_klass = Element.where(id: element_ids, element_klass_id: klass.id).pluck(:id)
      #   paginated_element_ids = Kaminari.paginate_array(element_ids_for_klass).page(page).per(page_size)
      #   serialized_elements = Element.find(paginated_element_ids).map do |element|
      #     Labimotion::ElementEntity.represent(element, displayed_in_list: true).serializable_hash
      #   end

      #   result["#{klass.name}s"] = {
      #     elements: serialized_elements,
      #     totalElements: element_ids_for_klass.size,
      #     page: page,
      #     pages: pages(element_ids_for_klass.size),
      #     perPage: page_size,
      #     ids: element_ids_for_klass,
      #   }
      # end
      # result
    end


    def gl_elements_search(col, params)
      # element_scope = Element.joins(:collections_elements).where(
      #   'collections_elements.collection_id = ? and collections_elements.element_type = (?)', collection.id, params[:selection][:genericElName]
      # )
      # if params[:selection][:searchName].present?
      #   element_scope = element_scope.where('name like (?)',
      #                                       "%#{params[:selection][:searchName]}%")
      # end
      # if params[:selection][:searchShowLabel].present?
      #   element_scope = element_scope.where('short_label like (?)', "%#{params[:selection][:searchShowLabel]}%")
      # end
      # if params[:selection][:searchProperties].present?
      #   params[:selection][:searchProperties] && params[:selection][:searchProperties][:layers] && params[:selection][:searchProperties][:layers].keys.each do |lk|
      #     layer = params[:selection][:searchProperties][:layers][lk]
      #     qs = layer[:fields].select { |f| f[:value].present? || f[:type] == 'input-group' }
      #     qs.each do |f|
      #       if f[:type] == 'input-group'
      #         sfs = f[:sub_fields].map { |e| { id: e[:id], value: e[:value] } }
      #         query = { "#{lk}": { fields: [{ field: f[:field].to_s, sub_fields: sfs }] } } if sfs.length > 0
      #       elsif f[:type] == 'checkbox' || f[:type] == 'integer' || f[:type] == 'system-defined'
      #         query = { "#{lk}": { fields: [{ field: f[:field].to_s, value: f[:value] }] } }
      #       else
      #         query = { "#{lk}": { fields: [{ field: f[:field].to_s, value: f[:value].to_s }] } }
      #       end
      #       element_scope = element_scope.where('properties @> ?', query.to_json)
      #     end
      #   end
      # end
      # element_scope
    end
  end
end
