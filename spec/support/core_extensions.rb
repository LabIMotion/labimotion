# frozen_string_literal: true

# rubocop:disable Rails/Present

module CoreExtensions
  module ObjectExtensions
    def blank?
      respond_to?(:empty?) ? empty? : !self
    end

    def present?
      !blank?
    end
  end

  module HashExtensions
    def compact_blank!
      reject! { |_, value| value.nil? || (value.respond_to?(:empty?) && value.empty?) }
      self
    end
  end
end

Object.include CoreExtensions::ObjectExtensions
Hash.include CoreExtensions::HashExtensions
