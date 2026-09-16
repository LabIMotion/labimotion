# frozen_string_literal: true

# Spec-process stand-in for gem-internal `Labimotion` class methods that
# specs may invoke without pulling in `lib/labimotion.rb`. Loading that file
# activates the gem-wide autoload table, which other specs (e.g.
# vocabulary_entity_spec) trip on by transitively requiring ActiveRecord
# models. Any spec that *does* require 'labimotion' will redefine these with
# the real implementations (last-def-wins) and is unaffected.
module Labimotion
  def self.log_exception(*); end
end
