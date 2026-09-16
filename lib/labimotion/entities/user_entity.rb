# frozen_string_literal: true

require 'labimotion/entities/application_entity'
module Labimotion
  # User entity
  class UserEntity < Labimotion::ApplicationEntity
    expose :id, :email, :first_name, :last_name, :name, :name_abbreviation
  end
end
