# frozen_string_literal: true
require 'labimotion/version'

module Labimotion
  ## ExportDataset
  class AttachmentHandler
    def self.copy(original_attach, element_id, element_type, current_user_id)
      copy_attach = Attachment.new(
        attachable_id: element_id,
        attachable_type: element_type,
        aasm_state: original_attach.aasm_state,
        created_by: current_user_id,
        created_for: current_user_id,
        filename: original_attach.filename,
      )
      copy_attach.save

      copy_io = original_attach.attachment_attacher.get.to_io
      attacher = copy_attach.attachment_attacher
      attacher.attach copy_io
      copy_attach.file_path = copy_io.path
      copy_attach.save

      Usecases::Attachments::Copy.update_annotation(original_attach.id, copy_attach.id) if (original_attach.attachment_data && original_attach.attachment_data['derivatives'])
      copy_attach
    end

  end
end