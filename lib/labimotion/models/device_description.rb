# frozen_string_literal: true

# This file extends the existing DeviceDescription model in the consuming app
# and defines a Labimotion::DeviceDescription wrapper for convenient access.

ActiveSupport.on_load(:active_record) do
  if defined?(::DeviceDescription)
    ::DeviceDescription.class_eval do
      include Labimotion::ElementFetchable

      def self.element_klass_name
        'device_description'
      end
    end
  else
    warn "[Labimotion] DeviceDescription is not defined when Labimotion extension was loaded."
  end
end

# Namespace wrapper to keep your preferred call style
module Labimotion
  module DeviceDescription
    # Delegate class methods to ::DeviceDescription
    def self.method_missing(method, *args, &block)
      if ::DeviceDescription.respond_to?(method)
        ::DeviceDescription.public_send(method, *args, &block)
      else
        super
      end
    end

    def self.respond_to_missing?(method, include_private = false)
      ::DeviceDescription.respond_to?(method, include_private) || super
    end
  end
end
