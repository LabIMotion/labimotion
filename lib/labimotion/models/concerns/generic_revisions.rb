# frozen_string_literal: true

# GenericRevisions concern
module Labimotion
  module GenericRevisions
    extend ActiveSupport::Concern
    included do
      after_create :create_vault
      after_update :save_to_vault
      before_destroy :delete_attachments
    end

    def create_vault
      save_to_vault unless self.class.name == 'Labimotion::Element'
    end

    def save_to_vault
      attributes = {
        uuid: uuid,
        klass_uuid: klass_uuid,
        properties: properties,
        properties_release: properties_release
      }
      attributes["#{Labimotion::Utils.element_name_dc(self.class.name)}_id"] = id
      attributes['name'] = name if self.class.name == 'Labimotion::Element'
      "#{self.class.name}sRevision".constantize.create(attributes)
    end

    def delete_attachments
      att_ids = []
      properties && properties['layers']&.keys&.each do |key|
        layer = properties['layers'][key]
        field_uploads = layer['fields'].select { |ss| ss['type'] == 'upload' }
        field_uploads.each do |field|
          (field['value'] && field['value']['files'] || []).each do |file|
            att_ids.push(file['aid']) unless file['aid'].nil?
          end
        end
      end
      Attachment.where(id: att_ids, attachable_id: id, attachable_type: %w[ElementProps SegmentProps]).destroy_all
    end
  end
end
