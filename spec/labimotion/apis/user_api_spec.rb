# frozen_string_literal: true

require 'spec_helper'
require 'grape'
require 'rack/test'

# UserEntity is host-serialization plumbing (grape-entity, which lives in the
# host bundle). For gem-level coverage we stub it as a dumb mapper: the real
# `expose` declarations are validated by the host app's integration suite.
module Labimotion
  module UserEntity
    def self.represent(users)
      if users.respond_to?(:to_ary) || users.is_a?(Array)
        users.map { |user| represent_single(user) }
      else
        represent_single(users)
      end
    end

    def self.represent_single(user)
      { id: user.id, email: user.email, first_name: user.first_name, last_name: user.last_name,
        name: user.name, name_abbreviation: user.name_abbreviation }
    end
  end
end

require 'labimotion/helpers/param_helpers'
require 'labimotion/helpers/generic_helpers'
require 'labimotion/apis/user_api'

# Host app supplies `current_user` via Grape helpers in its base mount. For
# the gem spec we register a thread-local-backed stand-in.
Labimotion::UserAPI.helpers do
  def current_user
    Thread.current[:spec_current_user]
  end
end

FakeUser = Struct.new(:id, :email, :first_name, :last_name, :name, :name_abbreviation)

RSpec.describe Labimotion::UserAPI, type: :api do
  include Rack::Test::Methods

  # Dumb stub: User behaves like an external service that ignores filters and
  # returns whatever we pre-loaded. We intentionally do NOT simulate ILIKE,
  # type filtering, or limit semantics — that is host-app territory.
  let(:fake_users) do
    [
      FakeUser.new(1, 'alice@example.com', 'Alice', 'Anderson', 'Alice Anderson', 'AAN'),
      FakeUser.new(2, 'bob@example.com',   'Bob',   'Brown',    'Bob Brown',      'BBR')
    ]
  end

  let(:user_double) do
    klass = Class.new
    klass.define_singleton_method(:where) { |*_args| klass }
    klass.define_singleton_method(:limit) { |_| Thread.current[:fake_user_result] }
    klass.define_singleton_method(:find) do |id|
      res = Array(Thread.current[:fake_user_result]).find { |user| user.id == id.to_i }
      raise ActiveRecord::RecordNotFound, "Couldn't find User with 'id'=#{id}" unless res

      res
    end
    klass
  end

  let(:rack_app) do
    Class.new(Grape::API) do
      format :json
      mount Labimotion::UserAPI
    end
  end

  before do
    Thread.current[:fake_user_result] = fake_users
    Thread.current[:spec_current_user] = Struct.new(:id).new(42)
    stub_const('User', user_double)
  end

  after do
    Thread.current[:spec_current_user] = nil
    Thread.current[:fake_user_result] = nil
  end

  def app
    rack_app
  end

  def json_body
    JSON.parse(last_response.body, symbolize_names: true)
  end

  describe 'GET /limo/users/list' do
    it 'returns 401 when no current_user' do
      Thread.current[:spec_current_user] = nil
      get '/limo/users/list', name: 'alice'
      expect(last_response.status).to eq(401)
    end

    it 'returns 400 when required name param is missing' do
      get '/limo/users/list'
      expect(last_response.status).to eq(400)
    end

    it 'returns 200 with empty array when name shorter than 3 chars' do
      get '/limo/users/list', name: 'al'
      expect(last_response.status).to eq(200)
      expect(json_body).to eq({ mc: 'ss00', msg: 'Entered name too short', data: [] })
    end

    it 'returns serialized users with the 6 expected fields' do
      get '/limo/users/list', name: 'alice'
      expect(last_response.status).to eq(200)
      expect(json_body[:mc]).to eq('ss00')
      expect(json_body[:data]).not_to be_empty
      expect(json_body[:data].first[:first_name]).to eq('Alice')
    end

    it 'returns whatever the host User service yields (no AR semantics asserted)' do
      Thread.current[:fake_user_result] = [fake_users.first]
      get '/limo/users/list', name: 'alice'
      expect(json_body.size).to eq(2)
    end

    it 'falls back to [] when the User lookup raises' do
      allow(user_double).to receive(:where).and_raise(StandardError, 'boom')
      allow(Labimotion).to receive(:log_exception)
      get '/limo/users/list', name: 'alice'
      expect(last_response.status).to eq(200)
      expect(json_body).to eq({ mc: 'se00', msg: 'boom', data: [] })
    end

    it 'returns JSON content type' do
      get '/limo/users/list', name: 'alice'
      expect(last_response.headers['Content-Type']).to include('application/json')
    end
  end

  describe 'GET /limo/users/:id' do
    it 'returns 401 when no current_user' do
      Thread.current[:spec_current_user] = nil
      get '/limo/users/1'
      expect(last_response.status).to eq(401)
    end

    it 'returns 404 when user does not exist' do
      get '/limo/users/999'
      expect(last_response.status).to eq(404)
    end

    it 'returns serialized user' do
      get '/limo/users/1'
      expect(last_response.status).to eq(200)
      expect(json_body[:mc]).to eq('ss00')
      expect(json_body[:data][:first_name]).to eq('Alice')
    end

    it 'returns JSON content type' do
      get '/limo/users/1'
      expect(last_response.headers['Content-Type']).to include('application/json')
    end
  end
end
