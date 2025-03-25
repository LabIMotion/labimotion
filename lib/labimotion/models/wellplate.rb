# frozen_string_literal: true

# This file extends the existing Wellplate model in the consuming app
# and defines a Labimotion::Wellplate wrapper for convenient access.

# rubocop:disable Style/RedundantConstantBase

ActiveSupport.on_load(:active_record) do
  if defined?(::Wellplate)
    ::Wellplate.class_eval do
      include Labimotion::ElementFetchable

      def self.element_klass_name
        'wellplate'
      end
    end
  else
    warn '[Labimotion] Wellplate is not defined when Labimotion extension was loaded.'
  end
end

# Namespace wrapper to keep your preferred call style
module Labimotion
  module Wellplate
    # Delegate class methods to ::Wellplate
    def self.method_missing(method, *args, &block)
      if ::Wellplate.respond_to?(method)
        ::Wellplate.public_send(method, *args, &block)
      else
        super
      end
    end

    def self.respond_to_missing?(method, include_private = false)
      ::Wellplate.respond_to?(method, include_private) || super
    end
  end
end

# rubocop:enable Style/RedundantConstantBase
