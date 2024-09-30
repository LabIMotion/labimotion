# frozen_string_literal: true

require 'labimotion/utils/utils'
require 'labimotion/libs/attachment_handler'

module Labimotion
  # Segmentable concern
  module Segmentable
    extend ActiveSupport::Concern
    included do
      has_many :segments, -> { select('DISTINCT ON (element_type, segment_klass_id) *').order(element_type: :asc, segment_klass_id: :asc, id: :desc) }, as: :element, dependent: :destroy, class_name: 'Labimotion::Segment'
    end

    def copy_segments(**args)
      return if args[:segments].nil?

      segments = save_segments(segments: args[:segments], current_user_id: args[:current_user_id])
      segments.each do |segment|
        properties = segment.properties
        properties[Labimotion::Prop::LAYERS].keys.each do |key|
          layer = properties[Labimotion::Prop::LAYERS][key]
          field_uploads = layer[Labimotion::Prop::FIELDS].select { |ss| ss['type'] == Labimotion::FieldType::UPLOAD }
          field_uploads&.each do |upload|
            idx = properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS].index(upload)
            files = upload["value"] && upload["value"]["files"]
            files&.each_with_index do |fi, fdx|
              aid = files[fdx]['aid']
              uid = files[fdx]['uid']
              next if aid.nil?

              att = Attachment.find_by(id: aid)
              att = Attachment.find_by(identifier: uid) if att.nil?
              copied_att = Labimotion::AttachmentHandler.copy(att, segment.id, Labimotion::Prop::SEGMENTPROPS, args[:current_user_id])

              if copied_att.nil?
                properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value']['files'].delete_at(fdx)
              else
                copied_att.save!
                properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value']['files'][fdx]['aid'] = copied_att.id
                properties[Labimotion::Prop::LAYERS][key][Labimotion::Prop::FIELDS][idx]['value']['files'][fdx]['uid'] = copied_att.identifier
              end
            end
          end
        end
        segment.update!(properties: properties)
      end
    end

    def save_segments(**args) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
      return if args[:segments].nil?

      segments = []
      args[:segments]&.each do |seg|
        klass = Labimotion::SegmentKlass.find_by(id: seg['segment_klass_id'])
        uuid = SecureRandom.uuid
        props = seg['properties']
        props['pkg'] = Labimotion::Utils.pkg(props['pkg'])
        props['identifier'] = klass.identifier if klass.identifier.present?
        props['uuid'] = uuid
        props['klass'] = 'Segment'
        props = Labimotion::SampleAssociation.update_sample_association(props, args[:current_user_id])
        current_user = User.find_by(id: args[:current_user_id])
        props = Labimotion::VocabularyHandler.update_vocabularies(props, current_user, self)
        segment = Labimotion::Segment.where(element_type: self.class.name, element_id: self.id, segment_klass_id: seg['segment_klass_id']).order(id: :desc).first
        if segment.present? && (segment.klass_uuid != props['klass_uuid'] || segment.properties != props)
          segment.update!(properties_release: klass.properties_release, properties: props, uuid: uuid, klass_uuid: props['klass_uuid'])
          segments.push(segment)
          Labimotion::Segment.where(element_type: self.class.name, element_id: self.id, segment_klass_id: seg['segment_klass_id']).where.not(id: segment.id).destroy_all
        end
        next if segment.present?

        props['klass_uuid'] = klass.uuid
        segment = Labimotion::Segment.create!(properties_release: klass.properties_release, segment_klass_id: seg['segment_klass_id'], element_type: self.class.name, element_id: self.id, properties: props, created_by: args[:current_user_id], uuid: uuid, klass_uuid: klass.uuid)
        segments.push(segment)
      end
      segments
    end
  end
end
