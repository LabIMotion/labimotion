# frozen_string_literal: true

require 'spec_helper'
require 'grape'
require 'rack/test'
require 'tempfile'
require_relative '../../support/element_variation_doubles'

# The host app owns Element, ElementPolicy, SegmentKlass and the
# ElementVariation model / entity. These stand-ins are injected per-example with
# `stub_const` rather than defined outright: defining `Labimotion::SegmentKlass`
# here would shadow the top-level `SegmentKlass` that vocabulary_entity_spec
# stubs, because constant lookup from inside `module Labimotion` finds the
# namespaced one first.
module ElementVariationApiStubs
  ElementModel = Class.new do
    def self.find(id)
      record = Thread.current[:spec_element]
      raise ActiveRecord::RecordNotFound if record.nil? || record.id != id.to_i

      record
    end
  end

  SegmentKlassModel = Class.new do
    def self.where(*)
      new
    end

    def to_a
      [ElementVariationDoubles.segment_klass]
    end
  end

  VariationModel = Class.new do
    def self.find_or_initialize_by(element_id:)
      Thread.current[:spec_variation_record] ||= ElementVariationDoubles.record
      Thread.current[:spec_variation_record].tap { |rec| rec.instance_variable_set(:@element_id, element_id) }
    end
  end

  Entity = Module.new do
    # Grape's `present` passes `env:` (and `root:`) through to the presenter.
    def self.represent(record, **_options)
      { id: 1, elementId: record.element_id, variations: record.variations, layout: record.layout }
    end
  end

  Policy = Class.new do
    def initialize(_user, _element); end

    def read?
      Thread.current[:spec_can_read] != false
    end

    def update?
      Thread.current[:spec_can_update] != false
    end
  end
end

require 'labimotion/libs/export_element_variations'
require 'labimotion/libs/import_element_variations'
require 'labimotion/apis/element_variation_api'

Labimotion::ElementVariationAPI.helpers do
  def current_user
    Thread.current[:spec_current_user]
  end
end

# The host mounts this API under a root that declares `format :json`; a bare
# Grape::API would default to :txt and never render JSON bodies.
class ElementVariationTestAPI < Grape::API
  format :json
  mount Labimotion::ElementVariationAPI
end

RSpec.describe Labimotion::ElementVariationAPI, type: :api do
  include Rack::Test::Methods

  def app
    ElementVariationTestAPI
  end

  let(:element) { ElementVariationDoubles.element }
  let(:record) { ElementVariationDoubles.record }

  before do
    stub_const('Labimotion::Element', ElementVariationApiStubs::ElementModel)
    stub_const('Labimotion::SegmentKlass', ElementVariationApiStubs::SegmentKlassModel)
    stub_const('Labimotion::ElementVariation', ElementVariationApiStubs::VariationModel)
    stub_const('Labimotion::ElementVariationEntity', ElementVariationApiStubs::Entity)
    stub_const('ElementPolicy', ElementVariationApiStubs::Policy)

    Thread.current[:spec_current_user] = Struct.new(:id, :name).new(1, 'Ada')
    Thread.current[:spec_element] = element
    Thread.current[:spec_variation_record] = record
    Thread.current[:spec_can_read] = true
    Thread.current[:spec_can_update] = true
    element.element_variation = record
  end

  after do
    %i[spec_current_user spec_element spec_variation_record spec_can_read spec_can_update]
      .each { |key| Thread.current[key] = nil }
  end

  def xlsx_upload(bytes, filename: 'variations.xlsx')
    file = Tempfile.new([File.basename(filename, '.xlsx'), '.xlsx'])
    file.binmode
    file.write(bytes)
    file.flush
    Rack::Test::UploadedFile.new(
      file.path,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      original_filename: filename,
    )
  end

  def exported_bytes
    Labimotion::ExportElementVariations.new(
      element, variation: record, segment_klasses: [ElementVariationDoubles.segment_klass]
    ).read
  end

  describe 'GET /element_variations/:element_id (pre-existing route)' do
    it 'still returns the variations as json' do
      get '/element_variations/42'

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['element_variation']['variations'].keys).to contain_exactly('uuid-a', 'uuid-b')
    end

    it 'is unaffected by the new nested export route' do
      get '/element_variations/42'
      expect(last_response.headers['Content-Disposition']).to be_nil
    end

    it 'refuses a user without read access' do
      Thread.current[:spec_can_read] = false
      get '/element_variations/42'
      expect(last_response.status).to eq(401)
    end

    it '404s for an unknown element' do
      get '/element_variations/999'
      expect(last_response.status).to eq(404)
    end
  end

  describe 'PUT /element_variations/:element_id (pre-existing route)' do
    it 'still upserts the variations' do
      put '/element_variations/42', { variations: { 'x' => { 'uuid' => 'x' } } }

      expect(last_response.status).to eq(200)
      expect(record.variations).to eq('x' => { 'uuid' => 'x' })
    end

    it 'refuses a user without update access' do
      Thread.current[:spec_can_update] = false
      put '/element_variations/42', { variations: { 'x' => { 'uuid' => 'x' } } }
      expect(last_response.status).to eq(401)
    end
  end

  describe 'GET /element_variations/:element_id/export' do
    it 'returns an xlsx attachment' do
      get '/element_variations/42/export'

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Type'])
        .to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      expect(last_response.body[0, 2]).to eq('PK')
    end

    it 'names the download after the element' do
      get '/element_variations/42/export'

      disposition = last_response.headers['Content-Disposition']
      expect(disposition).to include('attachment;')
      expect(disposition).to match(/filename="ME-1_variations_\d{8}_\d{6}\.xlsx"/)
      expect(disposition).to include("filename*=UTF-8''ME-1_variations_")
    end

    it 'refuses a user without read access' do
      Thread.current[:spec_can_read] = false
      get '/element_variations/42/export'
      expect(last_response.status).to eq(401)
    end
  end

  describe 'POST /element_variations/:element_id/import' do
    it 'accepts a file produced by the export and returns the record' do
      post '/element_variations/42/import', file: xlsx_upload(exported_bytes)

      expect(last_response.status).to eq(201)
      body = JSON.parse(last_response.body)
      expect(body['element_variation']['variations'].keys).to contain_exactly('uuid-a', 'uuid-b')
      expect(body['warnings']).to eq([])
    end

    it 'refuses a user without update access' do
      Thread.current[:spec_can_update] = false
      post '/element_variations/42/import', file: xlsx_upload(exported_bytes)
      expect(last_response.status).to eq(401)
    end

    it 'rejects a non-xlsx filename' do
      post '/element_variations/42/import', file: xlsx_upload(exported_bytes, filename: 'variations.csv')
      expect(last_response.status).to eq(400)
    end

    it 'maps an unreadable workbook to 422' do
      post '/element_variations/42/import', file: xlsx_upload('not a spreadsheet')

      expect(last_response.status).to eq(422)
      expect(last_response.body).to include('xlsx')
    end

    it 'requires a file' do
      post '/element_variations/42/import'
      expect(last_response.status).to eq(400)
    end
  end
end
