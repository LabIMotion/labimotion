# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'date'

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

    def self.handle_response(oat, response)
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

    def self.send_to_central_hub(klass, template, metadata, origin)
      body = {
        template_klass: klass,
        template: template,
        metadata: metadata,
        origin: origin
      }
      response = HTTParty.post(
        Labimotion::TemplateHub.uri('template_submissions'),
        headers: {
          'Content-Type' => 'application/json',
          'X-Origin-URL' => origin
        },
        body: body.to_json,
        timeout: 10
      )

      if [200, 201].include?(response.code)
        parsed_response = JSON.parse(response.body)
        return { mc: 'ss00', data: { id: parsed_response['id'] } }
      end
      { mc: 'se00', msg: "HTTP #{response.code}: #{response.message}", data: {} }
    rescue StandardError => e
      Labimotion.log_exception(e)
      { mc: 'se00', msg: "Connection failure: #{e.message}", data: {} }
    end
  end
end
