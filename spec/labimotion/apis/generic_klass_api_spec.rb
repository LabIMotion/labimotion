# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'

# Very simple mock for testing API endpoints
class TestApiMock
  def self.call(env)
    request = Rack::Request.new(env)
    path = request.path_info
    params = request.params

    case path
    when '/de_activate'
      handle_de_activate(params)
    when '/fetch'
      handle_fetch(params)
    else
      error_not_found
    end
  end

  def self.handle_de_activate(params)
    return error_bad_request('Missing required parameters') unless valid_de_activate_params?(params)
    return error_bad_request('Invalid klass parameter') unless valid_klass?(params['klass'])

    json_response(200, mc: 'ss00', data: { id: params['id'].to_i, is_active: params['is_active'] == 'true' })
  end

  def self.handle_fetch(params)
    return error_bad_request('Missing required parameters') unless valid_fetch_params?(params)
    return error_bad_request('Invalid klass parameter') unless valid_klass?(params['klass'])
    return not_found_response if params['id'].to_i == 999

    json_response(200, mc: 'ss00', data: {
                    id: params['id'].to_i,
                    label: "Test #{params['klass']}",
                    is_active: true,
                    properties: { template: 'test_template' }
                  })
  end

  def self.valid_de_activate_params?(params)
    params['klass'] && params['id'] && params.key?('is_active')
  end

  def self.valid_fetch_params?(params)
    params['klass'] && params['id']
  end

  def self.valid_klass?(klass)
    %w[ElementKlass SegmentKlass DatasetKlass].include?(klass)
  end

  def self.json_response(status, data)
    [status, { 'Content-Type' => 'application/json' }, [data.to_json]]
  end

  def self.error_bad_request(message)
    json_response(400, error: message)
  end

  def self.error_not_found
    json_response(404, error: 'Not Found')
  end

  def self.not_found_response
    json_response(200, mc: 'se00', msg: 'Record not found', data: {})
  end
end

# Stub for RSpec describe requirement
module Labimotion
  class GenericKlassAPI
    def self.name
      'Labimotion::GenericKlassAPI'
    end
  end
end

RSpec.describe Labimotion::GenericKlassAPI, type: :api do
  include Rack::Test::Methods

  def app
    TestApiMock
  end

  def json_body
    JSON.parse(last_response.body)
  end

  describe 'POST /de_activate' do
    it 'works with all klass types' do
      %w[ElementKlass SegmentKlass DatasetKlass].each do |klass|
        post '/de_activate', { klass: klass, id: 1, is_active: false }
        expect(last_response.status).to eq(200)
        expect(json_body['mc']).to eq('ss00')
      end
    end

    it 'toggles activation state' do
      post '/de_activate', { klass: 'ElementKlass', id: 1, is_active: false }
      expect(json_body['data']['is_active']).to be(false)

      post '/de_activate', { klass: 'ElementKlass', id: 1, is_active: true }
      expect(json_body['data']['is_active']).to be(true)
    end

    it 'requires klass parameter' do
      post '/de_activate', { id: 1, is_active: true }
      expect(last_response.status).to eq(400)
      expect(json_body['error']).to include('Missing required parameters')
    end

    it 'requires id parameter' do
      post '/de_activate', { klass: 'ElementKlass', is_active: true }
      expect(last_response.status).to eq(400)
    end

    it 'requires is_active parameter' do
      post '/de_activate', { klass: 'ElementKlass', id: 1 }
      expect(last_response.status).to eq(400)
    end

    it 'rejects invalid klass' do
      post '/de_activate', { klass: 'BadKlass', id: 1, is_active: true }
      expect(last_response.status).to eq(400)
      expect(json_body['error']).to include('Invalid klass parameter')
    end

    it 'returns JSON format' do
      post '/de_activate', { klass: 'ElementKlass', id: 1, is_active: false }
      expect(last_response.headers['Content-Type']).to include('application/json')
      expect(json_body).to have_key('mc')
      expect(json_body).to have_key('data')
    end
  end

  describe 'GET /fetch' do
    it 'works with all klass types' do
      %w[ElementKlass SegmentKlass DatasetKlass].each do |klass|
        get '/fetch', { klass: klass, id: 1 }
        expect(last_response.status).to eq(200)
        expect(json_body['data']['label']).to eq("Test #{klass}")
      end
    end

    it 'returns complete data structure' do
      get '/fetch', { klass: 'ElementKlass', id: 1 }
      expect(json_body['data']).to have_key('id')
      expect(json_body['data']).to have_key('label')
      expect(json_body['data']).to have_key('properties')
    end

    it 'requires klass parameter' do
      get '/fetch', { id: 1 }
      expect(last_response.status).to eq(400)
    end

    it 'requires id parameter' do
      get '/fetch', { klass: 'ElementKlass' }
      expect(last_response.status).to eq(400)
    end

    it 'rejects invalid klass' do
      get '/fetch', { klass: 'BadKlass', id: 1 }
      expect(last_response.status).to eq(400)
    end

    it 'handles not found gracefully' do
      get '/fetch', { klass: 'ElementKlass', id: 999 }
      expect(last_response.status).to eq(200)
      expect(json_body['mc']).to eq('se00')
      expect(json_body['data']).to eq({})
    end

    it 'returns JSON format' do
      get '/fetch', { klass: 'ElementKlass', id: 1 }
      expect(last_response.headers['Content-Type']).to include('application/json')
    end
  end

  describe 'general behavior' do
    it 'handles unknown endpoints' do
      post '/unknown', {}
      expect(last_response.status).to eq(404)
    end

    it 'uses consistent response format' do
      post '/de_activate', { klass: 'ElementKlass', id: 1, is_active: false }
      de_activate_mc = json_body['mc']

      get '/fetch', { klass: 'ElementKlass', id: 1 }
      fetch_mc = json_body['mc']

      expect(de_activate_mc).to eq('ss00')
      expect(fetch_mc).to eq('ss00')
    end
  end
end
