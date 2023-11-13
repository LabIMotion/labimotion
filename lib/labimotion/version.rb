# frozen_string_literal: true

## Labimotion Version
module Labimotion
  IS_RAILS5 = false
  VERSION_ELN = '1.0.19'
  VERSION_REPO = '0.3.1'

  VERSION = Labimotion::VERSION_REPO if Labimotion::IS_RAILS5 == true
  VERSION = Labimotion::VERSION_ELN if Labimotion::IS_RAILS5 == false
end
