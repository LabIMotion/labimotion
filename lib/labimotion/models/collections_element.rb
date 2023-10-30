# frozen_string_literal: true

module Labimotion
  class CollectionsElement < ApplicationRecord
    acts_as_paranoid
    self.table_name = :collections_elements
    belongs_to :collection
    belongs_to :element, class_name: 'Labimotion::Element'

    include Tagging
    include Collecting

    def self.get_elements_by_collection_type(collection_ids, type)
      self.where(collection_id: collection_ids, element_type: type).pluck(:element_id).compact.uniq
    end

    def self.remove_in_collection(eids, from_col_ids)
      element_ids = Labimotion::Element.get_associated_elements(eids)
      sample_ids = Labimotion::Element.get_associated_samples(element_ids)
      delete_in_collection(element_ids, from_col_ids)
      update_tag_by_element_ids(element_ids)
      CollectionsSample.remove_in_collection(sample_ids, from_col_ids)
    end

    def self.move_to_collection(eids, from_col_ids, to_col_ids, element_type='')
      element_ids = Labimotion::Element.get_associated_elements(eids)
      sample_ids = Labimotion::Element.get_associated_samples(element_ids)
      delete_in_collection(element_ids, from_col_ids)
      static_create_in_collection(element_ids, to_col_ids)
      CollectionsSample.move_to_collection(sample_ids, from_col_ids, to_col_ids)
      update_tag_by_element_ids(element_ids)
    end

    def self.create_in_collection(eids, to_col_ids, element_type='')
      element_ids = Labimotion::Element.get_associated_elements(eids)
      sample_ids = Labimotion::Element.get_associated_samples(element_ids)
      static_create_in_collection(element_ids, to_col_ids)
      CollectionsSample.create_in_collection(sample_ids, to_col_ids)
      update_tag_by_element_ids(element_ids)
    end
  end
end
