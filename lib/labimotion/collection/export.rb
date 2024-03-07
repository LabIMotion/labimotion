# frozen_string_literal: true

require 'labimotion/utils/export_utils'
module Labimotion
  ## Export
  class Export
    def self.fetch_element_klasses(&fetch_many)
      klasses = Labimotion::ElementKlass.where(is_active: true)
      fetch_many.call(klasses, {'created_by' => 'User'})
    rescue StandardError => e
      Labimotion.log_exception(e)
    end

    def self.fetch_segment_klasses(&fetch_many)
      klasses = Labimotion::SegmentKlass.where(is_active: true)
      fetch_many.call(klasses, {
        'element_klass_id' => 'Labimotion::ElementKlass',
        'created_by' => 'User'
        })
      rescue StandardError => e
        Labimotion.log_exception(e)
    end

    def self.fetch_dataset_klasses(&fetch_many)
      klasses = Labimotion::DatasetKlass.where(is_active: true)
      fetch_many.call(klasses, {'created_by' => 'User'})
    rescue StandardError => e
      Labimotion.log_exception(e)
    end

    def self.fetch_elements(collection, uuids, fetch_many, fetch_one, fetch_containers)
      attachments = []
      collection.elements.each do |element|
        fetch_one.call(element, {
          'element_klass_id' => 'Labimotion::ElementKlass',
          'created_by' => 'User',
        })
        fetch_containers.call(element)
      end
      collection.elements.each do |element|
        element, attachments = Labimotion::ExportUtils.fetch_properties(element, uuids, attachments, &fetch_one)
        fetch_one.call(element, {
          'element_klass_id' => 'Labimotion::ElementKlass',
          'created_by' => 'User',
        })
        attachments = Labimotion::Export.fetch_segments(element, uuids, attachments, &fetch_one)
      end
      fetch_many.call(collection.collections_elements, {
        'collection_id' => 'Collection',
        'element_id' => 'Labimotion::Element',
      })

      attachments
    rescue StandardError => e
      Labimotion.log_exception(e)
      attachments
    end

    def self.fetch_segments_prop(data, uuids)
      data.fetch(Labimotion::Prop::L_SEGMENT, {}).keys.each do |key|
        segment = data.fetch(Labimotion::Prop::L_SEGMENT, {})[key]
        Labimotion::ExportUtils.fetch_seg_properties(segment, uuids)
        data[Labimotion::Prop::L_SEGMENT][key] = segment
      end
      data
    rescue StandardError => e
      Labimotion.log_exception(e)
      data
    end

    def self.fetch_segments(element, uuids, attachments, &fetch_one)
      element_type = element.class.name
      segments = Labimotion::Segment.where("element_id = ? AND element_type = ?", element.id, element_type)
      segments.each do |segment|
        segment, attachments = Labimotion::ExportUtils.fetch_properties(segment, uuids, attachments, &fetch_one)
        fetch_one.call(segment, {
          'element_id' => segment.element_type,
          'segment_klass_id' => 'Labimotion::SegmentKlass',
          'created_by' => 'User'
        })
      end
      attachments
    rescue StandardError => e
      Labimotion.log_exception(e)
      attachments
    end

    def self.fetch_datasets(dataset, &fetch_one)
      return if dataset.nil?

      fetch_one.call(dataset, {
        'element_id' => 'Container',
      })
      fetch_one.call(dataset, {
        'element_id' => dataset.element_type,
        'dataset_klass_id' => 'Labimotion::DatasetKlass',
      })
      [dataset]
    rescue StandardError => e
      Labimotion.log_exception(e)
      [dataset]
    end
  end
end
