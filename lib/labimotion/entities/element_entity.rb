# frozen_string_literal: true

require 'labimotion/entities/properties_entity'
## TODO: Refactor labimotion to use the same entities as chemotion
module Labimotion
  class ElementEntity < PropertiesEntity
    with_options(anonymize_below: 0) do
      expose! :can_copy,        unless: :displayed_in_list
      expose! :can_publish,     unless: :displayed_in_list
      expose! :can_update,      unless: :displayed_in_list
      expose! :container,                           using: 'Entities::ContainerEntity'
      expose! :created_by
      expose! :id
      expose! :is_restricted
      expose! :klass_uuid
      expose! :name
      expose! :properties
      expose! :properties_release
      expose! :short_label
      expose! :thumb_svg
      expose! :type
      expose! :uuid
    end

    with_options(anonymize_below: 10) do
      expose! :element_klass, anonymize_with: nil,  using: 'Labimotion::ElementKlassEntity'
      expose! :segments,      anonymize_with: [],   using: 'Labimotion::SegmentEntity'
      expose! :tag,           anonymize_with: nil,  using: 'Entities::ElementTagEntity'
    end

    expose_timestamps


    private

    def is_restricted
      detail_levels[Labimotion::Element] < 10
    end

    def type
      object.element_klass.name # 'genericEl' #object.type
    end

    def can_update
      self.options[:policy].try(:update?) || false
    end

    def can_copy
      self.options[:policy].try(:copy?) || false
    end

    def can_publish
      self.options[:policy].try(:destroy?) || false
    end

  end
end
