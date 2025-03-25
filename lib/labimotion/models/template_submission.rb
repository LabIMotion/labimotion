# frozen_string_literal: true

# == Schema Information
#
# Table name: template_submissions
#
#  id            :bigint           not null, primary key
#  template_klass :string           not null
#  template      :jsonb            not null, default: {}
#  metadata      :jsonb            not null, default: {}
#  origin        :string           not null
#  state         :integer          not null, default: 0
#  created_at    :datetime         not null
#  updated_at    :datetime
#  deleted_at    :datetime
#
# Indexes
#
#  idx_template_submissions_template  (template) USING gin
#  idx_template_submissions_metadata  (metadata) USING gin
#

module Labimotion
  class TemplateSubmission < ApplicationRecord
    acts_as_paranoid

    # State enum
    enum state: {
      pending: 0,
      approved: 1,
      rejected: 2,
      released: 3
    }

    # Validations
    validates :template_klass, presence: true
    validates :template, presence: true
    validates :metadata, presence: true
    validates :origin, presence: true

    # Scopes
    scope :by_template_klass, ->(klass) { where(template_klass: klass) }
    scope :by_state, ->(state) { where(state: state) }
    scope :by_origin, ->(origin) { where(origin: origin) }
    scope :by_email, ->(email) { where("metadata->'submission'->>'email' = ?", email) }
    scope :by_contact_email, ->(email) { where("metadata->'submission'->>'contact_email' = ?", email) }
    scope :by_any_email, lambda { |email|
      where("metadata->'submission'->>'email' = ? OR metadata->'submission'->>'contact_email' = ?", email, email)
    }
    scope :recent, -> { order(created_at: :desc) }
  end
end
