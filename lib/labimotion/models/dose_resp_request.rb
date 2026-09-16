# frozen_string_literal: true

module Labimotion
  class DoseRespRequest < ApplicationRecord
    acts_as_paranoid
    self.table_name = :dose_resp_requests

    # Token generation
    has_secure_token :access_token

    # Callbacks
    before_create :generate_request_id

    # Associations
    belongs_to :element, class_name: 'Labimotion::Element'
    belongs_to :creator, foreign_key: :created_by, class_name: 'User'
    has_many :dose_resp_outputs, class_name: 'Labimotion::DoseRespOutput', dependent: :destroy

    # Validations
    validates :element, presence: true
    validates :creator, presence: true
    validates :expires_at, presence: true
    validates :state, inclusion: { in: [-1, 0, 1, 2] }
    validate :metadata_is_hash
    validate :input_metadata_is_hash

    # State constants
    STATE_ERROR = -1
    STATE_INITIAL = 0
    STATE_PROCESSING = 1
    STATE_COMPLETED = 2

    # Scopes
    scope :active, -> { where('expires_at > ?', Time.current).where(revoked_at: nil) }
    scope :expired, -> { where('expires_at <= ?', Time.current) }
    scope :revoked, -> { where.not(revoked_at: nil) }

    # Instance methods
    def expired?
      expires_at.present? && expires_at < Time.current
    end

    def revoked?
      revoked_at.present?
    end

    def active?
      !expired? && !revoked?
    end

    def revoke!
      update!(revoked_at: Time.current, state: STATE_ERROR)
    end

    def mark_processing!
      update!(state: STATE_PROCESSING) if state == STATE_INITIAL
    end

    def mark_completed!
      update!(state: STATE_COMPLETED)
    end

    def mark_error!(message = nil)
      update!(state: STATE_ERROR, resp_message: message)
    end

    def track_access!
      increment!(:access_count)
      update_columns(
        first_accessed_at: first_accessed_at || Time.current,
        last_accessed_at: Time.current
      )
    end

    private

    def metadata_is_hash
      return if wellplates_metadata.nil? || wellplates_metadata.is_a?(Hash)

      errors.add(:wellplates_metadata, 'must be a hash')
    end

    def input_metadata_is_hash
      return if input_metadata.nil? || input_metadata.is_a?(Hash)

      errors.add(:input_metadata, 'must be a hash')
    end

    def generate_request_id
      self.request_id = "MTT-#{Time.current.strftime('%Y%m%d-%H%M%S')}-#{SecureRandom.hex(3)}"
    end
  end
end
