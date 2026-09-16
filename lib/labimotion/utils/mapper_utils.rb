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

      # Extracts scalar values from Bruker array parameters such as
      #   ##$D= (0..63)
      #   0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.0002 ...
      # where the values live on the line(s) following the header. The config maps
      # each output key to an array name + index, e.g.
      #   { "D1" => { "name" => "D", "index" => 1 } } => D1 = the 2nd value (here 1).
      def extract_array_parameters(file_content, array_parameters)
        return {} if file_content.blank? || array_parameters.blank?

        lines = file_content.lines
        extracted = {}
        lines.each_with_index do |line, idx|
          header = line.match(/^\s*##\$(?<name>[A-Za-z0-9_]+)\s*=\s*\(\s*\d+\s*\.\.\s*\d+\s*\)/)
          next unless header

          targets = array_parameters.select { |_key, cfg| cfg['name'] == header[:name] }
          next if targets.empty?

          values = collect_array_values(lines, idx + 1)
          targets.each do |out_key, cfg|
            value = values[cfg['index'].to_i]
            extracted[out_key] = clean_value(value) if value.present?
          end
        end
        extracted.compact_blank!
        extracted
      rescue StandardError => e
        Rails.logger.error "Error extracting array parameters: #{e.message}"
        {}
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

      # Collects whitespace-separated values from the line(s) following an array
      # header, stopping at the next directive (line starting with '##') or a blank line.
      def collect_array_values(lines, start_index)
        values = []
        index = start_index
        while index < lines.length
          stripped = lines[index].strip
          break if stripped.empty? || stripped.start_with?('##')

          values.concat(stripped.split(/\s+/))
          index += 1
        end
        values
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
            process_file_entry(entry, source_config, final_parameters)
          elsif bagit_metadata_file?(entry)
            return { is_bagit: true, metadata: nil }
          end
        end
      end

      def process_file_entry(entry, source_config, final_parameters)
        file_content = entry.get_input_stream.read.force_encoding(Constants::File::ENCODING)
        extracted_parameters = extract_parameters(file_content, source_config['parameters'])
        final_parameters.merge!(extracted_parameters) if extracted_parameters.present?

        # Array parameters (e.g. D1 from acqus ##$D) are a fallback: they only fill a
        # value that an earlier/higher-priority source (e.g. parm.txt D1) did not provide.
        array_parameters = extract_array_parameters(file_content, source_config['arrayParameters'])
        final_parameters.reverse_merge!(array_parameters) if array_parameters.present?
      end

      def invalid_source_config?(source_config)
        source_config.nil? ||
          source_config['file'].nil? ||
          (source_config['parameters'].nil? && source_config['arrayParameters'].nil?)
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
