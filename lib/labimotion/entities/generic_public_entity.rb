# frozen_string_literal: true

require 'labimotion/entities/application_entity'

# Entity module
module Labimotion
  class GenericPublicEntity < Labimotion::ApplicationEntity
    expose! :uuid
    expose! :name
    expose! :desc
    expose! :icon_name
    expose! :klass_prefix
    expose :klass_name do |obj|
      obj[:name] || ''
    end
    expose! :label
    expose! :identifier
    expose! :version
    expose! :released_at
    expose :properties_release, **DISPLAYED_IN_LIST_CONDITION, anonymize_with: {}
    expose :metadata, **DISPLAYED_IN_LIST_CONDITION, anonymize_with: {}
    expose :element_klass do |obj|
      if obj[:element_klass_id]
        { label: obj.element_klass.label, icon_name: obj.element_klass.icon_name, id: obj.element_klass_id }
      else
        {}
      end
    end
  end
end
