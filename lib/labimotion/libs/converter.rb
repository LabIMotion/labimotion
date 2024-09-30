# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'date'
require 'labimotion/version'
require 'labimotion/utils/utils'

# rubocop: disable Metrics/AbcSize
# rubocop: disable Metrics/MethodLength
# rubocop: disable Metrics/ClassLength
# rubocop: disable Metrics/CyclomaticComplexity

module Labimotion
  class Converter
    def self.logger
      @@converter_logger ||= Logger.new(Rails.root.join('log/converter.log')) # rubocop:disable Style/ClassVars
    end

    def self.process_ds(id, current_user = {})
      att = Attachment.find_by(id: id, con_state: Labimotion::ConState::CONVERTED)
      return if att.nil? || att.attachable_id.nil? || att.attachable_type != 'Container' || att.filename.split('.')&.last != 'zip'

      eln_ds = Container.find_by(id: att.attachable_id, container_type: 'dataset')
      return if eln_ds.nil? || eln_ds.parent.nil? || eln_ds.parent&.container_type != 'analysis'

      dsr = []
      ols = nil
      Zip::File.open(att.attachment_attacher.file.url) do |zip_file|
        res = Labimotion::Converter.collect_metadata(zip_file, current_user) if att.filename.split('.')&.last == 'zip'
        ols = res[:o] unless res&.dig(:o).nil?
        dsr.push(res[:d]) unless res&.dig(:d).nil?
      end
      dsr.flatten!
      dataset = build_ds(att.attachable_id, ols)
      update_ds(dataset, dsr, current_user) if dataset.present?
      att.update_column(:con_state, Labimotion::ConState::COMPLETED)
    rescue StandardError => e
      Labimotion::Converter.logger.error ["Att ID: #{att&.id}, OLS: #{ols}", "DSR: #{dsr}", e.message, *e.backtrace].join($INPUT_RECORD_SEPARATOR)
      raise e
    end

    def self.uri(api_name)
      url = Rails.configuration.converter.url
      "#{url}#{api_name}"
    end

    def self.timeout
      Rails.configuration.try(:converter).try(:timeout) || 30
    end

    def self.extname
      '.jdx'
    end

    def self.client_id
      Rails.configuration.converter.profile || ''
    end

    def self.secret_key
      Rails.configuration.converter.secret_key || ''
    end

    def self.auth
      { username: client_id, password: secret_key }
    end

    def self.date_time
      DateTime.now.strftime('%Q')
    end

    def self.signature(jbody)
      md5 = Digest::MD5.new
      md5.update jbody
      mdhex = md5.hexdigest
      mdall = mdhex << secret_key
      @signature = Digest::SHA1.hexdigest mdall
    end

    def self.header(opt = {})
      opt || {}
    end

    def self.vor_conv(id)
      conf = Rails.configuration.try(:converter).try(:url)
      oa = Attachment.find(id)
      folder = Rails.root.join('tmp/uploads/converter')
      FileUtils.mkdir_p(folder)
      return nil if conf.nil? || oa.nil?

      { a: oa, f: folder }
    end

    def self.collect_metadata(zip_file, current_user = {}) # rubocop: disable Metrics/PerceivedComplexity
      dsr = []
      ols = nil
      zip_file.each do |entry|
        next unless entry.name == 'metadata/converter.json'

        metadata = entry.get_input_stream.read.force_encoding('UTF-8')
        jdata = JSON.parse(metadata)

        ols = jdata['ols']
        matches = jdata['matches']
        matches&.each do |match|
          idf = match['identifier']
          idr = match['result']
          if idf&.class == Hash && idr&.class == Hash && !idf['outputLayer'].nil? && !idf['outputKey'].nil? && !idr['value'].nil? # rubocop:disable Layout/LineLength
            dsr.push(layer: idf['outputLayer'], field: idf['outputKey'], value: idr['value'])
          end
        end
      end
      { d: dsr, o: ols }
    end

    def self.handle_response(oat, response, current_user = {}) # rubocop: disable Metrics/PerceivedComplexity
      dsr = []
      ols = nil

      begin
        tmp_file = Tempfile.new(encoding: 'ascii-8bit')
        tmp_file.write(response.parsed_response)
        tmp_file.rewind

        filename = oat.filename
        name = "#{File.basename(filename, '.*')}.zip"
        att = Attachment.new(
          filename: name,
          file_path: tmp_file.path,
          ## content_type: file[:type],
          attachable_id: oat.attachable_id,
          attachable_type: 'Container',
          con_state: Labimotion::ConState::CONVERTED,
          created_by: oat.created_by,
          created_for: oat.created_for,
        )

        att.save! if att.valid?

        process_ds(att.id, current_user)
      rescue StandardError => e
        raise e
      ensure
        tmp_file&.close
      end
    end

    def self.process(data, current_user = {}) # rubocop: disable Metrics/PerceivedComplexity
      return data[:a].con_state if data[:a]&.attachable_type != 'Container'
      response = nil
      begin
        ofile = Rails.root.join(data[:f], data[:a].filename)
        FileUtils.cp(data[:a].attachment_url, ofile)

        File.open(ofile, 'r') do |f|
          body = { file: f }
          response = HTTParty.post(
            uri('conversions'),
            basic_auth: auth,
            body: body,
            timeout: timeout,
          )
        end
        if response.ok?
          Labimotion::Converter.handle_response(data[:a], response, current_user)
          Labimotion::ConState::PROCESSED
        else
          Labimotion::Converter.logger.error ["Converter Response Error: id: [#{data[:a]&.id}], filename: [#{data[:a]&.filename}], response: #{response}"].join($INPUT_RECORD_SEPARATOR)
          Labimotion::ConState::ERROR
        end
      rescue StandardError => e
        Labimotion::Converter.logger.error ["process fail: #{data[:a]&.id}", e.message, *e.backtrace].join($INPUT_RECORD_SEPARATOR)
        Labimotion::ConState::ERROR
      ensure
        FileUtils.rm_f(ofile)
      end
    end

    def self.jcamp_converter(id, current_user = {})
      data = Labimotion::Converter.vor_conv(id)
      return if data.nil?

      Labimotion::Converter.process(data, current_user)
    rescue StandardError => e
      Labimotion::Converter.logger.error ["jcamp_converter fail: #{id}", e.message, *e.backtrace].join($INPUT_RECORD_SEPARATOR)
      Labimotion::ConState::ERROR
    end

    def self.generate_ds(att_id, current_user = {})
      dsr_info = Labimotion::Converter.fetch_dsr(att_id)
      begin
        return unless dsr_info && dsr_info[:info]&.length.positive?

        dataset = Labimotion::Converter.build_ds(att_id, dsr_info[:ols])
        Labimotion::Converter.update_ds(dataset, dsr_info[:info], current_user) if dataset.present?
      rescue StandardError => e
        Labimotion::Converter.logger.error ["Att ID: #{att_id}, OLS: #{dsr_info[:ols]}", "DSR: #{dsr_info[:info]}", e.message, *e.backtrace].join($INPUT_RECORD_SEPARATOR)
      ensure
        Labimotion::Converter.clean_dsr(att_id)
      end
    end

    def self.build_ds(att_id, ols)
      cds = Container.find_by(id: att_id)
      dataset = Labimotion::Dataset.find_by(element_type: 'Container', element_id: cds.id)
      return dataset unless dataset.nil?

      klass = Labimotion::DatasetKlass.find_by(ols_term_id: ols)
      return if klass.nil?

      uuid = SecureRandom.uuid
      props = klass.properties_release
      props['uuid'] = uuid
      props['pkg'] = Labimotion::Utils.pkg(props['pkg'])
      props['klass'] = 'Dataset'
      Labimotion::Dataset.create!(
        uuid: uuid,
        dataset_klass_id: klass.id,
        element_type: 'Container',
        element_id: cds.id,
        properties: props,
        properties_release: klass.properties_release,
        klass_uuid: klass.uuid
      )
    end

    def self.update_ds(dataset, dsr, current_user = nil) # rubocop: disable Metrics/PerceivedComplexity
      layers = dataset.properties[Labimotion::Prop::LAYERS] || {}
      new_prop = dataset.properties
      dsr.each do |ds|
        layer = layers[ds[:layer]]
        next if layer.blank? || layer[Labimotion::Prop::FIELDS].blank?

        fields = layer[Labimotion::Prop::FIELDS].select{ |f| f['field'] == ds[:field] }
        fi = fields&.first
        next if fi.blank?

        idx = layer[Labimotion::Prop::FIELDS].find_index(fi)
        fi['value'] = ds[:value]
        fi['device'] = ds[:device] || ds[:value]
        new_prop[Labimotion::Prop::LAYERS][ds[:layer]][Labimotion::Prop::FIELDS][idx] = fi
      end
      element = Container.find(dataset.element_id)&.root_element
      new_prop = Labimotion::VocabularyHandler.update_vocabularies(new_prop, current_user, element)
      dataset.properties = new_prop
      dataset.save!
    end

    def self.ts(method, identifier, params = nil)
      Rails.cache.send(method, "#{Labimotion::Converter.new.class.name}#{identifier}", params)
    end

    def self.fetch_dsr(att_id)
      Labimotion::Converter.ts('read', att_id)
    end

    def self.clean_dsr(att_id)
      Labimotion::Converter.ts('delete', att_id)
    end

    def self.fetch_options
      options = { basic_auth: auth, timeout: timeout }
      response = HTTParty.get(uri('options'), options)
      response.parsed_response if response.code == 200
    end

    def self.delete_profile(id)
      options = { basic_auth: auth, timeout: timeout }
      response = HTTParty.delete("#{uri('profiles')}/#{id}", options)
      response.parsed_response if response.code == 200
    end

    def self.create_profile(data)
      options = { basic_auth: auth, timeout: timeout, body: data.to_json, headers: { 'Content-Type' => 'application/json' } }
      response = HTTParty.post(uri('profiles'), options)
      response.parsed_response if response.code == 201
    end

    def self.update_profile(data)
      options = { basic_auth: auth, timeout: timeout, body: data.to_json, headers: { 'Content-Type' => 'application/json' } }
      response = HTTParty.put("#{uri('profiles')}/#{data[:id]}", options)
      response.parsed_response if response.code == 200
    end

    def self.fetch_profiles
      options = { basic_auth: auth, timeout: timeout }
      response = HTTParty.get(uri('profiles'), options)
      response.parsed_response if response.code == 200
    end

    def self.create_tables(tmpfile)
      res = {}
      File.open(tmpfile.path, 'r') do |file|
        body = { file: file }
        response = HTTParty.post(
          uri('tables'),
          basic_auth: auth,
          body: body,
          timeout: timeout,
        )
        res = response.parsed_response
      end
      res
    end

    def self.metadata(id, current_user)
      att = Attachment.find(id)
      return if att.nil? || att.attachable_id.nil? || att.attachable_type != Labimotion::Prop::CONTAINER

      ds = Labimotion::Dataset.find_by(element_type: Labimotion::Prop::CONTAINER, element_id: att.attachable_id)
      att.update_column(:con_state, Labimotion::ConState::COMPLETED) if ds.present?
      process_ds(att.id, current_user) if ds.nil?
    end
  end
end

# rubocop: enable Metrics/AbcSize
# rubocop: enable Metrics/MethodLength
# rubocop: enable Metrics/ClassLength
# rubocop: enable Metrics/CyclomaticComplexity
