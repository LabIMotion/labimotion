# frozen_string_literal: true

module Labimotion
  ## Generic Klass Revisions Helpers
  module GenericKlassRevisions
    extend ActiveSupport::Concern
    included do
      # has_many :element_klasses_revisions, dependent: :destroy
      before_save :check_identifier
    end

    def check_identifier
      self.identifier = identifier || SecureRandom.uuid if self.has_attribute?(:identifier)
    end

    def create_klasses_revision(current_user)
      properties_release = properties_template
      migrate_workflow if properties_release['flow'].present?

      if properties_release['flowObject'].present?
        elements = (properties_release['flowObject']['nodes'] || []).map do |el|
          if el['data'].present? && el['data']['lKey'].present?
            layer = properties_release[Labimotion::Prop::LAYERS][el['data']['lKey']]
            el['data']['layer'] = layer if layer.present?
          end
          el
        end
        properties_release['flowObject']['nodes'] = elements
      end
      klass_attributes = {
        uuid: properties_template['uuid'],
        properties_template: properties_release,
        properties_release: properties_release,
        released_at: DateTime.now,
        updated_by: current_user&.id,
        released_by: current_user&.id,
      }

      self.update!(klass_attributes)
      reload
      attributes = {
        released_by: released_by,
        uuid: uuid,
        version: version,
        created_by: updated_by,
        properties_release: properties_release,
        released_at: released_at
      }
      attributes["#{self.class.name.underscore.split('/').last}_id"] = id
      "#{self.class.name}esRevision".constantize.create(attributes)
    end
  end
end
