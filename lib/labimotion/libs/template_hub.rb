# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'date'

# rubocop: disable Metrics/AbcSize
# rubocop: disable Metrics/MethodLength

module Labimotion
  ## TemplateHub
  class TemplateHub
    TARGET = Rails.env.production? ? 'https://www.chemotion-repository.net/' : 'http://localhost:3000/'

    def self.uri(api_name)
      url = TARGET
      "#{url}api/v1/labimotion_hub/#{api_name}"
    end


    def self.header(opt = {})
      opt || { timeout: 10, headers: { 'Content-Type' => 'text/json' } }
    end

    def self.handle_response(oat, response) # rubocop: disable Metrics/PerceivedComplexity
      begin
        response&.success? ? 'OK' : 'ERROR'
      rescue StandardError => e
        raise e
      ensure
        ## oat.update(status: response&.success? ? 'done' : 'failure')
      end
    end

    def self.list(klass)
      body = { klass: klass }
      response = HTTParty.get("#{uri('list')}?klass=#{klass}", timeout: 10)
      # response.parsed_response if response.code == 200
      JSON.parse(response.body) if response.code == 200
    rescue StandardError => e
      Labimotion.log_exception(e)
      error!('Cannot connect to Chemotion Repository', 401)
    end

    def self.fetch_identifier(klass, identifier, origin)
      body = { klass: klass, identifier: identifier, origin: origin }
      response = HTTParty.post(
        uri('fetch'),
        body: body,
        timeout: 10
      )
      # response.parsed_response if response.code == 200
      JSON.parse(response.body) if response.code == 201
    rescue StandardError => e
      Labimotion.log_exception(e)
      error!('Cannot connect to Chemotion Repository', 401)
    end
  end
end

# rubocop: enable Metrics/AbcSize
# rubocop: enable Metrics/MethodLength
# rubocop: enable Metrics/ClassLength
# rubocop: enable Metrics/CyclomaticComplexity
