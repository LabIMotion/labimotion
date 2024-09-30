# frozen_string_literal: true
#
require 'labimotion/entities/application_entity'
module Labimotion
  # Dataset entity
  class VocabularyEntity < ApplicationEntity
    expose :id, :identifier, :name, :label, :field_type, :opid, :term_id,
           :field_id, :properties, :source, :source_id, :layer_id
    expose :voc do |obj|
      voc = (obj[:properties] && obj[:properties]['voc']) || {}

      case voc['source']
      when Labimotion::Prop::ELEMENT
        voc['source_name'] = ElementKlass.find_by(identifier: voc['source_id'])&.label
        # if voc['identifier'] == 'element.name'
          # voc['source_name'] = ElementKlass.find_by(identifier: voc['source_id'])&.name
        # end
      when Labimotion::Prop::SEGMENT
        voc['source_name'] = SegmentKlass.find_by(identifier: voc['source_id'])&.label
      when Labimotion::Prop::DATASET
        voc['source_name'] = DatasetKlass.find_by(identifier: voc['source_id'])&.label
      end
      voc
    end
    expose :ontology do |obj|
      (obj[:properties] && obj[:properties]['ontology']) || {}
    end
  end
end
