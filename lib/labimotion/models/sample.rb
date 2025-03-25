# frozen_string_literal: true

# This file extends the existing Sample model in the consuming app
# and defines a Labimotion::Sample wrapper for convenient access.

ActiveSupport.on_load(:active_record) do
  if defined?(::Sample)
    ::Sample.class_eval do
      include Labimotion::ElementFetchable

      def self.element_klass_name
        'sample'
      end
    end
  else
    warn "[Labimotion] Sample is not defined when Labimotion extension was loaded."
  end
end

# Namespace wrapper to keep your preferred call style
module Labimotion
  module Sample
    # Delegate class methods to ::Sample
    def self.method_missing(method, *args, &block)
      if ::Sample.respond_to?(method)
        ::Sample.public_send(method, *args, &block)
      else
        super
      end
    end

    def self.respond_to_missing?(method, include_private = false)
      ::Sample.respond_to?(method, include_private) || super
    end
  end
end
