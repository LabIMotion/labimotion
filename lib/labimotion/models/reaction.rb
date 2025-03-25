# frozen_string_literal: true

# This file extends the existing Reaction model in the consuming app
# and defines a Labimotion::Reaction wrapper for convenient access.

ActiveSupport.on_load(:active_record) do
  if defined?(::Reaction)
    ::Reaction.class_eval do
      include Labimotion::ElementFetchable

      def self.element_klass_name
        'reaction'
      end
    end
  else
    warn "[Labimotion] Reaction is not defined when Labimotion extension was loaded."
  end
end

# Namespace wrapper to keep your preferred call style
module Labimotion
  module Reaction
    # Delegate class methods to ::Reaction
    def self.method_missing(method, *args, &block)
      if ::Reaction.respond_to?(method)
        ::Reaction.public_send(method, *args, &block)
      else
        super
      end
    end

    def self.respond_to_missing?(method, include_private = false)
      ::Reaction.respond_to?(method, include_private) || super
    end
  end
end
