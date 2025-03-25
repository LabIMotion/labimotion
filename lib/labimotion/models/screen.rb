# frozen_string_literal: true

# This file extends the existing Screen model in the consuming app
# and defines a Labimotion::Screen wrapper for convenient access.

ActiveSupport.on_load(:active_record) do
  if defined?(::Screen)
    ::Screen.class_eval do
      include Labimotion::ElementFetchable

      def self.element_klass_name
        'screen'
      end
    end
  else
    warn "[Labimotion] Screen is not defined when Labimotion extension was loaded."
  end
end

# Namespace wrapper to keep your preferred call style
module Labimotion
  module Screen
    # Delegate class methods to ::Screen
    def self.method_missing(method, *args, &block)
      if ::Screen.respond_to?(method)
        ::Screen.public_send(method, *args, &block)
      else
        super
      end
    end

    def self.respond_to_missing?(method, include_private = false)
      ::Screen.respond_to?(method, include_private) || super
    end
  end
end
