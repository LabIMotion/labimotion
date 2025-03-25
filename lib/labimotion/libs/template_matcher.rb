# frozen_string_literal: true

module Labimotion
  class TemplateMatcher
    def self.find_best_match(ols_term_id)
      return { template: nil, match_type: nil, info_messages: [] } if ols_term_id.blank?

      info_messages = []

      # Step 1: Find "assigned" mode templates
      assigned = Labimotion::DatasetKlass.find_assigned_templates(ols_term_id)
      if assigned.any?
        handle_multiple_results(assigned, :assigned, info_messages)
        return { template: assigned.first, match_type: 'assigned', info_messages: info_messages }
      end

      # Step 2: Find exact match template
      exact = Labimotion::DatasetKlass.find_by(ols_term_id: ols_term_id)
      return { template: exact, match_type: 'exact', info_messages: info_messages } if exact

      # Step 3: Find "inferred" mode templates
      info_messages << 'Using parent template'
      inferred = Labimotion::DatasetKlass.find_inferred_templates(ols_term_id)
      if inferred.any?
        handle_multiple_results(inferred, :inferred, info_messages)
        return { template: inferred.first, match_type: 'inferred', info_messages: info_messages }
      end

      { template: nil, match_type: nil, info_messages: info_messages }
    end

    def self.handle_multiple_results(templates, mode, info_messages)
      return unless templates.size > 1

      ols_ids = templates.map(&:ols_term_id).join(', ')
      info_messages << "Multiple #{mode} templates found, ols_term_id(s) are #{ols_ids}"
    end
  end
end
