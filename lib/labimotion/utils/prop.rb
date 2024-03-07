module Labimotion
  ## Converter State
  class Prop
    LAYERS = 'layers'.freeze
    FIELDS = 'fields'.freeze
    SUBFIELDS = 'sub_fields'.freeze
    SUBVALUES = 'sub_values'.freeze
    SEL_OPTIONS = 'select_options'.freeze
    L_DATASET_KLASS = 'Labimotion::DatasetKlass'.freeze
    L_ELEMENT_KLASS = 'Labimotion::ElementKlass'.freeze
    L_SEGMENT_KLASS = 'Labimotion::SegmentKlass'.freeze
    L_ELEMENT = 'Labimotion::Element'.freeze
    L_SEGMENT = 'Labimotion::Segment'.freeze
    L_DATASET = 'Labimotion::Dataset'.freeze
    SEGMENT = 'Segment'.freeze
    ELEMENT = 'Element'.freeze
    DATASET = 'Dataset'.freeze
    SAMPLE = 'Sample'.freeze
    MOLECULE = 'Molecule'.freeze
    REACTION = 'Reaction'.freeze
    CONTAINER = 'Container'.freeze
    ELEMENTPROPS = 'ElementProps'.freeze
    SEGMENTPROPS = 'SegmentProps'.freeze
    DATASETPROPS = 'DatasetProps'.freeze
    UPLOADPROPS = [ELEMENTPROPS, SEGMENTPROPS, DATASETPROPS].freeze
  end
end
