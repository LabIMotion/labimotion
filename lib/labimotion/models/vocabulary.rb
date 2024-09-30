# frozen_string_literal: true
require 'labimotion/models/concerns/generic_klass_revisions'
require 'labimotion/models/concerns/workflow'

module Labimotion
  class Vocabulary < ApplicationRecord
    self.table_name = :vocabularies
    acts_as_paranoid


  end
end
