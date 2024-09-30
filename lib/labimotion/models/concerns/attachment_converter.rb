# frozen_string_literal: true

module Labimotion
  module AttachmentConverter
    ACCEPTED_FORMATS = (Rails.configuration.try(:converter).try(:ext) || []).freeze
    extend ActiveSupport::Concern

    included do
      before_create :init_converter
      after_update :exec_converter
      def init_converter
        return if self.has_attribute?(:con_state) == false || con_state.present?

        if Rails.configuration.try(:converter).try(:url) && ACCEPTED_FORMATS.include?(File.extname(filename&.downcase))
          self.con_state = Labimotion::ConState::WAIT
        end

        if File.extname(filename&.downcase) == '.zip' && attachable&.dataset.nil?
          self.con_state = Labimotion::ConState::NMR
        end

        self.con_state = Labimotion::ConState::NONE if con_state.nil?
      end

      def exec_converter
        return if self.has_attribute?(:con_state) == false || self.con_state.nil? || self.con_state == Labimotion::ConState::NONE

        return if attachable_id.nil? && con_state != Labimotion::ConState::WAIT

        current_user = User.find_by(id: created_by)
        case con_state
        when Labimotion::ConState::NMR
          self.con_state = Labimotion::NmrMapper.process_ds(id, current_user)
          update_column(:con_state, con_state)
        when Labimotion::ConState::WAIT
          self.con_state = Labimotion::Converter.jcamp_converter(id, current_user)
          update_column(:con_state, con_state)
        when Labimotion::ConState::CONVERTED
          Labimotion::Converter.metadata(id, current_user)
        end
      end
    end
  end
end
