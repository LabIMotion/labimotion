# frozen_string_literal: true

module Labimotion
  class HubLog < ApplicationRecord
    self.table_name = :hub_logs
    belongs_to :klass, polymorphic: true, optional: true
  end
end
