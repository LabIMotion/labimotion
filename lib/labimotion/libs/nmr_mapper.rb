# frozen_string_literal: true

require 'labimotion/libs/dataset_builder'
require 'labimotion/version'
require 'labimotion/utils/mapper_utils'
require 'labimotion/utils/utils'

module Labimotion
  ## NmrMapper
  class NmrMapper
    # Constants specific to NMR mapping
    module Constants
      # Duplicate fields that need special handling
      DUP_FIELDS = %w[time version].freeze

      # Field groups for different processing stages
      FG_FINALIZE = %w[set.temperature general.date general.time software.Name software.Version].freeze
      FG_SYSTEM = %w[general.creator sample_details.label sample_details.id].freeze

      # Valid NMR nuclei types
      OBSERVED = %w[1H 13C].freeze

      # OLS terms for different NMR types
      module OlsTerms
        NMR_1H = 'CHMO:0000593'
        NMR_13C = 'CHMO:0000595'
      end
    end

    class << self
      def process_ds(id, current_user = {})
        att = find_attachment(id)
        return Labimotion::ConState::NONE if att.nil?

        result = process(att)
        return Labimotion::ConState::NONE if result.nil?

        handle_process_result(result, att, id, current_user)
      end

      def process(att)
        config = Labimotion::MapperUtils.load_brucker_config
        return if config.nil?

        attacher = att&.attachment_attacher
        extracted_data = Labimotion::MapperUtils.extract_data_from_zip(attacher&.file&.url, config['sourceMap'])
        return if extracted_data.nil?

        extracted_data[:parameters] = config['sourceMap']['parameters']
        extracted_data
      end

      def generate_ds(_id, cid, data, current_user = {}, element = nil)
        return if data.nil? || cid.nil?

        obj = Labimotion::NmrMapper.build_ds(cid, data[:content])
        return if obj.nil? || obj[:ols].nil?

        Labimotion::NmrMapper.update_ds(cid, obj, current_user, element)
      end

      def update_ds(_cid, obj, current_user, element)
        dataset = obj[:dataset]
        dataset.properties = process_prop(obj, current_user, element)
        dataset.save!
      end

      def build_ds(id, content)
        ds = find_container(id)
        return if ds.nil? || content.nil?

        Labimotion::DatasetBuilder.build(ds, content)
      end

      private

      def finalize_ds(new_prop)
        Constants::FG_FINALIZE.each do |field_path|
          field = Labimotion::Utils.find_field(new_prop, field_path)
          next unless field

          update_finalized_field(field)
        end
        new_prop
      end

      def sys_to_ds(new_prop, element, current_user)
        Constants::FG_SYSTEM.each do |field_path|
          field = Labimotion::Utils.find_field(new_prop, field_path)
          next unless field

          update_system_field(field, current_user, element)
        end
        new_prop
      end

      def params_to_ds(obj, new_prop)
        metadata = obj[:metadata]
        parameters = obj[:parameters]

        parameters.each do |param_key, field_path|
          next if skip_parameter?(metadata, param_key)

          update_param_field(new_prop, field_path, param_key, metadata)
        end
        new_prop
      end

      def process_prop(obj, current_user, element)
        new_prop = obj[:dataset].properties
        new_prop
          .then { |prop| params_to_ds(obj, prop) }
          .then { |prop| sys_to_ds(prop, element, current_user) }
          .then { |prop| finalize_ds(prop) }
          .then { |prop| Labimotion::VocabularyHandler.update_vocabularies(prop, current_user, element) }
      end

      def find_attachment(id)
        Attachment.find_by(id: id, con_state: Labimotion::ConState::NMR)
      end

      def handle_process_result(result, att, id, current_user)
        if result[:is_bagit]
          handle_bagit_result(att, id, current_user)
        elsif invalid_metadata?(result)
          Labimotion::ConState::NONE
        else
          handle_nmr_result(result, att, current_user)
        end
      end

      def handle_bagit_result(att, id, current_user)
        att.update_column(:con_state, Labimotion::ConState::CONVERTED)
        Labimotion::Converter.metadata(id, current_user)
        Labimotion::ConState::COMPLETED
      end

      def invalid_metadata?(result)
        result[:metadata].nil? ||
          Constants::OBSERVED.exclude?(result[:metadata]['NUC1'])
      end

      def handle_nmr_result(result, att, current_user)
        ds = find_container(att.attachable_id)
        return Labimotion::ConState::NONE unless valid_container?(ds)

        prepare_mapper_result(ds, result, current_user)
        Labimotion::ConState::COMPLETED
      end

      def find_container(cid)
        Container.find_by(id: cid)
      end

      def valid_container?(container)
        container.present? &&
          container.parent&.container_type == 'analysis' &&
          container.root_element.present?
      end

      def prepare_mapper_result(container, result, current_user)
        metadata = result[:metadata]
        ols = determine_ols_term(metadata['NUC1'])

        data = {
          content: {
            metadata: metadata,
            ols: ols,
            parameters: result[:parameters]
          }
        }

        generate_ds(nil, container.id, data, current_user, container.root_element)
      end

      def determine_ols_term(nuc1)
        case nuc1
        when '1H' then Constants::OlsTerms::NMR_1H
        when '13C' then Constants::OlsTerms::NMR_13C
        end
      end

      def skip_parameter?(metadata, param_key)
        metadata[param_key.to_s].blank? &&
          Constants::DUP_FIELDS.exclude?(param_key.to_s.downcase)
      end

      def update_param_field(properties, field_path, param_key, metadata)
        field = Labimotion::Utils.find_field(properties, field_path)
        return unless field

        update_field_value(field, param_key, metadata)
        update_field_extend(field, param_key, metadata)
      end

      def update_duplicate_field(field_name, metadata)
        case field_name
        when 'time' then metadata['DATE']
        when 'Version' then metadata['TITLE']
        end
      end

      def update_field_value(field, param_key, metadata)
        field['value'] = format_field_value(field, param_key, metadata)
      rescue StandardError => e
        Rails.logger.error "Error converting value for #{param_key}: #{e.message}"
        field['value'] = ''
      end

      def format_field_value(field, param_key, metadata)
        if field['type'] == 'integer'
          Integer(metadata[param_key.to_s])
        elsif Constants::DUP_FIELDS.include?(param_key.to_s.downcase)
          update_duplicate_field(field['field'], metadata)
        else
          metadata[param_key.to_s]
        end
      end

      def update_finalized_field(field)
        case field['field']
        when 'temperature'
          field['value_system'] = 'K'
        when 'date', 'time'
          field['value'] = Labimotion::MapperUtils.format_timestamp(field['value'], field['field'])
        when 'Name'
          field['value'] = 'TopSpin' if field['value'].to_s.include?('TopSpin')
        when 'Version'
          field['value'] = field['value'].to_s.split('TopSpin').last.strip if field['value'].to_s.include?('TopSpin')
        end
      end

      def update_system_field(field, current_user, element)
        field['value'] = determine_field_value(field['field'], current_user, element)
      end

      def determine_field_value(field_name, current_user, element)
        case field_name
        when 'creator'
          current_user&.name if current_user.present?
        when 'label', 'id'
          get_sample_value(field_name, element)
        end
      end

      def get_sample_value(field_name, element)
        return unless element.present? && element.is_a?(Sample)

        field_name == 'label' ? element.short_label : element.id
      end

      def update_field_extend(field, param_key, metadata)
        field['device'] = metadata[param_key.to_s]
        field['dkey'] = param_key.to_s
      end
    end
  end
end
