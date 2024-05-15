# frozen_string_literal: true

require 'labimotion/utils/import_utils'
module Labimotion
  class Import
    def self.import_repo_segment_props(instances, attachments, attachable_uuid, fields)
      primary_store = Rails.configuration.storage.primary_store
      attachable = instances.fetch('Labimotion::Segment').fetch(attachable_uuid)
      attachment = Attachment.where(id: attachments, filename: fields.fetch('identifier')).first
      attachment.update!(
        attachable_id: attachable.id,
        attachable_type: Labimotion::Prop::SEGMENTPROPS,
        con_state: Labimotion::ConState::NONE,
        transferred: true,
        aasm_state: fields.fetch('aasm_state'),
        filename: fields.fetch('filename'),
        content_type: fields.fetch('content_type'),
        storage: primary_store
        # checksum: fields.fetch('checksum'),
        # created_at: fields.fetch('created_at'),
        # updated_at: fields.fetch('updated_at')
      )

      properties = attachable.properties
      properties[Labimotion::Prop::LAYERS].keys.each do |key|
        layer = properties[Labimotion::Prop::LAYERS][key]
        field_uploads = layer[Labimotion::Prop::FIELDS].select { |ss| ss['type'] == Labimotion::FieldType::UPLOAD }
        field_uploads&.each do |upload|
          idx = properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS].index(upload)
          files = upload["value"] && upload["value"]["files"]
          files&.each_with_index do |fi, fdx|
            if properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value']['files'][fdx]['uid'] == fields.fetch('identifier')
              properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value']['files'][fdx]['aid'] = attachment.id
              properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value']['files'][fdx]['uid'] = attachment.identifier
            end
          end
        end
      end
      attachable.update!(properties: properties)
      attachment
    rescue StandardError => e
      Labimotion.log_exception(e)
      attachment
    end

    def self.import_datasets(data, instances, gt, current_user_id, &update_instances)
      begin
        data.fetch('Labimotion::Dataset', {}).each do |uuid, fields|
          klass_id = fields['dataset_klass_id']
          next if data.fetch('Labimotion::DatasetKlass', {}).empty?

          dk_obj = data.fetch('Labimotion::DatasetKlass', {}) && data.fetch('Labimotion::DatasetKlass', {})[klass_id]
          next if dk_obj.nil?

          dk_id = dk_obj && dk_obj['identifier']
          element_uuid = fields.fetch('element_id')
          element_type = fields.fetch('element_type')
          element = instances.fetch(element_type).fetch(element_uuid)

          dataset_klass = Labimotion::DatasetKlass.find_by(identifier: dk_id) if dk_id.present?
          next if gt == true && dataset_klass.nil?

          dkr = Labimotion::DatasetKlassesRevision.find_by(uuid: fields.fetch('klass_uuid'))
          dataset_klass = dkr.dataset_klass if dataset_klass.nil? && dkr.present?
          next if dataset_klass.nil? || dataset_klass.ols_term_id != dk_obj['ols_term_id']

          dataset_klass = Labimotion::DatasetKlass.find_by(ols_term_id: dk_obj['ols_term_id']) if dataset_klass.nil?
          next if dataset_klass.nil?

          dataset = Labimotion::Dataset.create!(
            fields.slice(
              'properties', 'properties_release'
            ).merge(
              ## created_by: current_user_id,
              element: element,
              dataset_klass: dataset_klass,
              uuid: SecureRandom.uuid,
              klass_uuid: dkr&.uuid || dataset_klass.uuid
            )
          )
          update_instances.call(uuid, dataset)
        end
      rescue StandardError => e
        Labimotion.log_exception(e)
        # raise
      end
    end

    def self.import_segments(data, instances, attachments, gt, current_user_id, &update_instances)
      data.fetch(Labimotion::Prop::L_SEGMENT, {}).each do |uuid, fields|
        klass_id = fields["segment_klass_id"]
        sk_obj = data.fetch(Labimotion::Prop::L_SEGMENT_KLASS, {})[klass_id]
        sk_id = sk_obj["identifier"]
        ek_obj = data.fetch(Labimotion::Prop::L_ELEMENT_KLASS).fetch(sk_obj["element_klass_id"])
        element_klass = Labimotion::ElementKlass.find_by(name: ek_obj['name']) if ek_obj.present?
        next if element_klass.nil? || ek_obj.nil? # || ek_obj['is_generic'] == true

        element_uuid = fields.fetch('element_id')
        element_type = fields.fetch('element_type')
        element = instances.fetch(element_type).fetch(element_uuid)
        segment_klass = Labimotion::SegmentKlass.find_by(identifier: sk_id) if sk_id.present?
        segment_klass = Labimotion::SegmentKlass.find_by(uuid: fields.fetch('klass_uuid')) if segment_klass.nil?

        if segment_klass.nil?
          skr = Labimotion::SegmentKlassesRevision.find_by(uuid: fields.fetch('klass_uuid'))
          segment_klass = Labimotion::SegmentKlass.find_by(id: skr.segment_klass_id) if skr.present?
        end

        next if segment_klass.nil? || element.nil?

        ## segment_klass = Labimotion::ImportUtils.create_segment_klass(sk_obj, segment_klass, element_klass, current_user_id)

        segment = Labimotion::Segment.create!(
          fields.slice(
            'properties', 'properties_release'
          ).merge(
            created_by: current_user_id,
            element: element,
            segment_klass: segment_klass,
            uuid: SecureRandom.uuid,
            klass_uuid: skr&.uuid || segment_klass.uuid
          )
        )
        properties = Labimotion::ImportUtils.properties_handler(data, instances, attachments, segment, nil)
        segment.update!(properties: properties)
        update_instances.call(uuid, segment)
      end

      Labimotion::ImportUtils.process_ai(data, instances)
    rescue StandardError => e
      Labimotion.log_exception(e)
      raise
    end

    def self.import_elements(data, instances, attachments, gt, current_user_id, fetch_many, &update_instances)
      elements = {}
      data.fetch('Labimotion::Element', {}).each do |uuid, fields|
        klass_id = fields["element_klass_id"]
        ek_obj = data.fetch('Labimotion::ElementKlass', {})[klass_id]
        ek_id = ek_obj["identifier"] if ek_obj.present?
        element_klass = Labimotion::ElementKlass.find_by(identifier: ek_id) if ek_id.present?
        element_klass = Labimotion::ElementKlass.find_by(uuid: fields.fetch('klass_uuid')) if element_klass.nil?

        if element_klass.nil?
          ekr = Labimotion::ElementKlassesRevision.find_by(uuid: fields.fetch('klass_uuid'))
          element_klass = ekr.element_klass if element_klass.nil? && ekr.present?
        end
        next if element_klass.nil?

        element = Labimotion::Element.create!(
          fields.slice(
            'name', 'properties', 'properties_release'
          ).merge(
            created_by: current_user_id,
            element_klass: element_klass,
            collections: fetch_many.call(
              'Collection', 'Labimotion::CollectionsElement', 'element_id', 'collection_id', uuid
            ),
            uuid: SecureRandom.uuid,
            klass_uuid: ekr&.uuid || element_klass.uuid
          )
        )
        elements[uuid] = element
      end
      elements.keys.each do |uuid, element|
        element = elements[uuid]
        properties = Labimotion::ImportUtils.properties_handler(data, instances, attachments, element, elements)
        element.update!(properties: properties)
        update_instances.call(uuid, element)
        element.container = Container.create_root_container
        element.save!
      end
    rescue StandardError => e
      Labimotion.log_exception(e)
      raise
    end
  end
end
