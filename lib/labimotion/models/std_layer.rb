# frozen_string_literal: true

module Labimotion
  class StdLayer < ApplicationRecord
    acts_as_paranoid
    self.table_name = :layers
    has_many :layer_tracks, primary_key: 'identifier', foreign_key: 'identifier', class_name: 'Labimotion::StdLayersRevision'
  end
end
