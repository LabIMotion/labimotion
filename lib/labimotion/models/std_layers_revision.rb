# frozen_string_literal: true

module Labimotion
  class StdLayersRevision < ApplicationRecord
    acts_as_paranoid
    self.table_name = :layer_tracks
    belongs_to :layers, primary_key: 'identifier', foreign_key: 'identifier', class_name: 'Labimotion::StdLayer'
  end
end
