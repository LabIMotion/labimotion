# frozen_string_literal: true

module Labimotion
  # Helper for associated sample
  module SampleAssociationHelpers
    extend Grape::API::Helpers

    def build_sample(sid, cols, current_user, cr_opt)
      Labimotion::SampleAssociation.build_sample(sid, cols, current_user, cr_opt)
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      nil
    end

    def build_table_sample(field_tables, current_user, element)
      Labimotion::SampleAssociation.build_table_sample(field_tables, current_user, element)
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      []
    end

    def update_sample_association(properties, current_user, element)
      Labimotion::SampleAssociation.update_sample_association(properties, current_user, element)
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
    end
  end
end
