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
    expose! :klass_name
    expose! :label
    expose! :identifier
    expose! :version
    expose! :released_at
    expose! :properties_release, if: :displayed
    expose :element_klass do |obj|
      if obj[:element_klass_id]
        { :label => obj.element_klass.label, :icon_name => obj.element_klass.icon_name }
      else
        {}
      end
    end
  end
end
