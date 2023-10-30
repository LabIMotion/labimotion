module Labimotion
  # Segmentable concern
  module Workflow
    extend ActiveSupport::Concern

    def split_workflow(properties)
      return if properties['flow'].nil?

      if properties['flow'].present?
        properties['flowObject'] = {}
        elements = properties['flow']['elements'] || {}
        properties['flowObject']['nodes'] = elements.select { |obj| obj['source'].nil? }
        properties['flowObject']['edges'] = elements.select { |obj| obj['source'] && obj['source'] != obj['target'] }.map do |obj|
          obj['markerEnd'] = { 'type': 'arrowclosed' }
          obj
        end
        properties['flowObject']['viewport'] = {
          "x": properties['flow']['position'][0] || 0,
          "y": properties['flow']['position'][1] || 0,
          "zoom": properties['flow']['zoom'] || 1
        }
        properties.delete('flow')
      end
      properties
    end

    def migrate_workflow
      return if properties_template.nil? || properties_release.nil?

      return if properties_template['flow'].nil? && properties_release['flow'].nil?

      update_column(:properties_template, split_workflow(properties_template)) if properties_template['flow']
      update_column(:properties_release, split_workflow(properties_release)) if properties_release['flow']
    end
  end
end
