# frozen_string_literal: true

require 'labimotion/utils/utils'
require 'labimotion/version'

module Labimotion
  class DatasetBuilder
    def self.build(container, content)
      return unless valid_input?(container, content)

      create_dataset_with_metadata(container, content)
    end

    private

    def self.valid_input?(container, content)
      container.present? &&
        content.present? &&
        content[:ols].present? &&
        content[:metadata].present?
    end

    def self.create_dataset_with_metadata(container, content)
      klass = find_dataset_klass(content[:ols])
      return unless klass

      dataset = create_dataset(container, klass)
      build_result(dataset, content)
    end

    def self.find_dataset_klass(ols_term_id)
      result = Labimotion::TemplateMatcher.find_best_match(ols_term_id)
      result[:template]
    end

    def self.create_dataset(container, klass)
      uuid = SecureRandom.uuid
      props = prepare_properties(klass, uuid)

      Labimotion::Dataset.create!(
        uuid: uuid,
        dataset_klass_id: klass.id,
        element_type: 'Container',
        element_id: container.id,
        properties: props,
        properties_release: klass.properties_release,
        klass_uuid: klass.uuid,
        metadata: klass.metadata
      )
    end

    def self.prepare_properties(klass, uuid)
      props = klass.properties_release
      props['uuid'] = uuid
      props['pkg'] = Labimotion::Utils.pkg(props['pkg'])
      props['klass'] = 'Dataset'
      props
    end

    def self.build_result(dataset, content)
      {
        dataset: dataset,
        metadata: content[:metadata],
        ols: content[:ols],
        parameters: content[:parameters]
      }
    end

    private_class_method :valid_input?, :create_dataset_with_metadata, :find_dataset_klass, :create_dataset,
                         :prepare_properties, :build_result
  end
end
