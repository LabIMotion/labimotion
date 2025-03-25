# frozen_string_literal: true

# Datasetable concern
require 'labimotion/utils/utils'

module Labimotion
  ## Datasetable concern
  module Datasetable
    extend ActiveSupport::Concern

    included do
      has_one :dataset, as: :element, class_name: 'Labimotion::Dataset'
    end

    def not_dataset?
      self.class.name == 'Container' && container_type != 'dataset'
    end

    def copy_dataset(orig_ds)
      return if orig_ds.dataset.nil?

      ods = orig_ds.dataset
      uuid = SecureRandom.uuid
      dataset = Labimotion::Dataset.create!(
        uuid: uuid,
        dataset_klass_id: ods.dataset_klass_id,
        element_type: 'Container',
        element_id: self.id,
        properties: ods.properties,
        properties_release: ods.properties_release,
        klass_uuid: ods.klass_uuid,
        metadata: ods.metadata || {}
      )
    end

    def save_dataset(**dataset_args)
      return if not_dataset?

      args = dataset_args[:dataset]
      dataset_klass_id = args[:dataset_klass_id]
      klass = Labimotion::DatasetKlass.find_by(id: dataset_klass_id)
      uuid = SecureRandom.uuid
      metadata = args[:metadata] || {}
      props = args[:properties]
      props['pkg'] = Labimotion::Utils.pkg(props['pkg'])
      props['identifier'] = klass.identifier if klass.identifier.present?
      props['uuid'] = uuid
      props['klass'] = 'Dataset'
      props['klass_uuid'] = klass.uuid
      props = Labimotion::VocabularyHandler.update_vocabularies(props, dataset_args[:current_user], dataset_args[:element])

      ds = Labimotion::Dataset.find_by(element_type: self.class.name, element_id: id)
      if ds.present? && (ds.klass_uuid != klass.uuid || ds.properties != props || ds.metadata != metadata)
        ds.update!(properties_release: klass.properties_release, uuid: uuid, dataset_klass_id: dataset_klass_id, properties: props, klass_uuid: klass.uuid, metadata: metadata)
      end
      return if ds.present?

      Labimotion::Dataset.create!(properties_release: klass.properties_release, uuid: uuid, dataset_klass_id: dataset_klass_id, element_type: self.class.name, element_id: id, properties: props, klass_uuid: klass.uuid, metadata: metadata)
    end

    def destroy_datasetable
      return if not_dataset?

      Labimotion::Dataset.where(element_type: self.class.name, element_id: id).destroy_all
    end
  end
end
