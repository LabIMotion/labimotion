# frozen_string_literal: true

require 'json'
require 'time'
require 'zip'
require 'labimotion/constants'

module Labimotion
  class MapperUtils
    class << self
      def load_config(config_json)
        JSON.parse(config_json)
      rescue JSON::ParserError => e
        Rails.logger.error "Error parsing JSON: #{e.message}"
        nil
      rescue Errno::ENOENT => e
        Rails.logger.error "Config file not found at #{Constants::Mapper::NMR_CONFIG}: #{e.message}"
        nil
      rescue StandardError => e
        Rails.logger.error "Unexpected error loading config: #{e.message}"
        nil
      end

      def load_brucker_config
        config = load_config(File.read(Constants::Mapper::NMR_CONFIG))
        return if config.nil? || config['sourceMap'].nil?

        source_selector = config['sourceMap']['sourceSelector']
        return if source_selector.blank?

        parameters = config['sourceMap']['parameters']
        return if parameters.blank?

        config
      end

      def extract_data_from_zip(zip_file_url, source_map)
        return nil if zip_file_url.nil?

        process_zip_file(zip_file_url, source_map)
      rescue Zip::Error => e
        Rails.logger.error "Zip file error: #{e.message}"
        nil
      rescue StandardError => e
        Rails.logger.error "Unexpected error extracting metadata: #{e.message}"
        nil
      end

      def extract_parameters(file_content, parameter_names)
        return nil if file_content.blank? || parameter_names.blank?

        patterns = {
          standard: build_parameter_pattern(parameter_names, :standard),
          parm: build_parameter_pattern(parameter_names, :parm)
        }

        extracted_parameters = {}
        begin
          file_content.each_line do |line|
            if (match = match_parameter(line, patterns))
              value = clean_value(match[:value])
              extracted_parameters[match[:param_name]] = value
            end
          end
        rescue StandardError => e
          Rails.logger.error "Error reading file content: #{e.message}"
          return nil
        end
        extracted_parameters.compact_blank!
        extracted_parameters
      end

      def format_timestamp(timestamp_str, give_format = nil)
        return nil if timestamp_str.blank?

        begin
          timestamp = Integer(timestamp_str)
          time_object = Time.at(timestamp).in_time_zone(Constants::DateTime::TIME_ZONE)
          case give_format
          when 'date'
            time_object.strftime(Constants::DateTime::DATE_FORMAT)
          when 'time'
            time_object.strftime(Constants::DateTime::TIME_FORMAT)
          else
            time_object.strftime(Constants::DateTime::DATETIME_FORMAT)
          end
        rescue ArgumentError, TypeError => e
          Rails.logger.error "Error parsing timestamp '#{timestamp_str}': #{e.message}"
          nil
        end
      end

      private

      def build_parameter_pattern(parameter_names, format)
        pattern = case format
                  when :standard
                    '^\\s*##?\\s*[$]?(?<param_name>%s)\\s*(?:=\\s*)?(?<value>.*?)\\s*$'
                  when :parm
                    '^\\s*(?<param_name>%s)\\s+(?<value>[^\\s].*?)(?:\\s+[A-Za-z]+)?\\s*$'
                  end

        param_regex = parameter_names.map { |p| "\\b#{Regexp.escape(p)}\\b" }.join('|')
        Regexp.new(pattern % param_regex)
      end

      def match_parameter(line, patterns)
        patterns.each_value do |pattern|
          match = line.match(pattern)
          return match if match
        end
        nil
      end

      def clean_value(value)
        value = value.strip
        value = value[1..-2].strip if value.start_with?('<') && value.end_with?('>')
        value
      end

      def process_zip_file(zip_file_url, source_map)
        final_parameters = {}

        Zip::File.open(zip_file_url) do |zip_file|
          source_map['sourceSelector'].each do |source_name|
            process_source(zip_file, source_map[source_name], final_parameters)
          end
        end

        return { is_bagit: false, metadata: final_parameters } if final_parameters.present?

        nil
      end

      def process_source(zip_file, source_config, final_parameters)
        return if invalid_source_config?(source_config)

        zip_file.each do |entry|
          if source_file?(entry, source_config)
            process_file_entry(entry, source_config['parameters'], final_parameters)
          elsif bagit_metadata_file?(entry)
            return { is_bagit: true, metadata: nil }
          end
        end
      end

      def process_file_entry(entry, parameters, final_parameters)
        file_content = entry.get_input_stream.read.force_encoding(Constants::File::ENCODING)
        extracted_parameters = extract_parameters(file_content, parameters)
        final_parameters.merge!(extracted_parameters) if extracted_parameters.present?
      end

      def invalid_source_config?(source_config)
        source_config.nil? ||
          source_config['file'].nil? ||
          source_config['parameters'].nil?
      end

      def source_file?(entry, source_config)
        entry.name.include?(source_config['file'])
      end

      def bagit_metadata_file?(entry)
        entry.name.include?('metadata/') &&
          entry.name.include?('converter.json')
      end
    end
  end
end
