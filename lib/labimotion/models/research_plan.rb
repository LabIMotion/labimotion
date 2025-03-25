# frozen_string_literal: true

# This file extends the existing ResearchPlan model in the consuming app
# and defines a Labimotion::ResearchPlan wrapper for convenient access.

# rubocop:disable Style/RedundantConstantBase

ActiveSupport.on_load(:active_record) do
  if defined?(::ResearchPlan)
    ::ResearchPlan.class_eval do
      include Labimotion::ElementFetchable

      def self.element_klass_name
        'research_plan'
      end
    end
  else
    warn '[Labimotion] ResearchPlan is not defined when Labimotion extension was loaded.'
  end
end

# Namespace wrapper to keep your preferred call style
module Labimotion
  module ResearchPlan
    # Delegate class methods to ::ResearchPlan
    def self.method_missing(method, *args, &block)
      if ::ResearchPlan.respond_to?(method)
        ::ResearchPlan.public_send(method, *args, &block)
      else
        super
      end
    end

    def self.respond_to_missing?(method, include_private = false)
      ::ResearchPlan.respond_to?(method, include_private) || super
    end
  end
end

# rubocop:enable Style/RedundantConstantBase
