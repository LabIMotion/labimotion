# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require 'httparty'
require 'logger'

# Mock Rails class (only if not already defined)
unless defined?(Rails)
  class Rails
    def self.logger
      @logger ||= Logger.new($stdout)
    end

    def self.env
      @env ||= ActiveSupport::StringInquirer.new('test')
    end
  end
end

# Add env method to Rails if it doesn't exist
if defined?(Rails) && !Rails.respond_to?(:env)
  class Rails
    def self.env
      @env ||= ActiveSupport::StringInquirer.new('test')
    end
  end
end

# Mock ActiveSupport::StringInquirer
module ActiveSupport
  class StringInquirer < String
    def production?
      self == 'production'
    end

    def test?
      self == 'test'
    end
  end
end

# Mock Labimotion.log_exception
module Labimotion
  def self.log_exception(_exception, _user = nil)
    # Mock - do nothing
  end
end

require_relative '../../../lib/labimotion/libs/template_hub'

RSpec.describe Labimotion::TemplateHub do
  describe '.send_to_central_hub' do
    let(:klass) { 'ElementKlass' }
    let(:template) { { name: 'Test Template', version: '1.0.0' } }
    let(:metadata) do
      {
        klass: {
          klass: 'ElementKlass',
          data: { id: 1, label: 'Test' }
        },
        submission: {
          email: 'user@example.com',
          contact_email: 'contact@example.com',
          application: 'Testing',
          message: 'Test submission'
        }
      }
    end
    let(:origin) { 'http://localhost:3000' }
    let(:api_url) { 'http://localhost:3000/api/v1/labimotion_hub/template_submissions' }

    before do
      WebMock.disable_net_connect!(allow_localhost: false)
    end

    after do
      WebMock.reset!
    end

    context 'when submission is successful' do
      it 'returns success with status code 200' do
        stub_request(:post, api_url)
          .with(
            headers: {
              'Content-Type' => 'application/json',
              'X-Origin-URL' => origin
            },
            body: {
              template_klass: klass,
              template: template,
              metadata: metadata,
              origin: origin
            }.to_json
          )
          .to_return(
            status: 200,
            body: { id: 123 }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        result = described_class.send_to_central_hub(klass, template, metadata, origin)

        expect(result[:mc]).to eq('ss00')
        expect(result[:data][:id]).to eq(123)
      end

      it 'returns success with status code 201' do
        stub_request(:post, api_url)
          .to_return(
            status: 201,
            body: { id: 456 }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        result = described_class.send_to_central_hub(klass, template, metadata, origin)

        expect(result[:mc]).to eq('ss00')
        expect(result[:data][:id]).to eq(456)
      end

      it 'sends correct request body structure' do
        stub = stub_request(:post, api_url)
          .with(
            body: hash_including(
              'template_klass' => klass,
              'template' => template,
              'metadata' => hash_including('submission'),
              'origin' => origin
            )
          )
          .to_return(status: 200, body: { id: 1 }.to_json)

        described_class.send_to_central_hub(klass, template, metadata, origin)

        expect(stub).to have_been_requested
      end

      it 'sends correct headers' do
        stub = stub_request(:post, api_url)
          .with(
            headers: {
              'Content-Type' => 'application/json',
              'X-Origin-URL' => origin
            }
          )
          .to_return(status: 200, body: { id: 1 }.to_json)

        described_class.send_to_central_hub(klass, template, metadata, origin)

        expect(stub).to have_been_requested
      end
    end

    context 'when submission fails' do
      it 'returns error for 400 status code' do
        stub_request(:post, api_url)
          .to_return(
            status: 400,
            body: { error: 'Bad Request' }.to_json
          )

        result = described_class.send_to_central_hub(klass, template, metadata, origin)

        expect(result[:mc]).to eq('se00')
        expect(result[:msg]).to include('HTTP 400')
        expect(result[:data]).to eq({})
      end

      it 'returns error for 401 status code' do
        stub_request(:post, api_url)
          .to_return(status: 401, body: 'Unauthorized')

        result = described_class.send_to_central_hub(klass, template, metadata, origin)

        expect(result[:mc]).to eq('se00')
        expect(result[:msg]).to include('HTTP 401')
      end

      it 'returns error for 422 status code' do
        stub_request(:post, api_url)
          .to_return(
            status: 422,
            body: { errors: ['Validation failed'] }.to_json
          )

        result = described_class.send_to_central_hub(klass, template, metadata, origin)

        expect(result[:mc]).to eq('se00')
        expect(result[:msg]).to include('HTTP 422')
      end

      it 'returns error for 500 status code' do
        stub_request(:post, api_url)
          .to_return(status: 500, body: 'Internal Server Error')

        result = described_class.send_to_central_hub(klass, template, metadata, origin)

        expect(result[:mc]).to eq('se00')
        expect(result[:msg]).to include('HTTP 500')
      end

      it 'returns error for 503 status code' do
        stub_request(:post, api_url)
          .to_return(status: 503, body: 'Service Unavailable')

        result = described_class.send_to_central_hub(klass, template, metadata, origin)

        expect(result[:mc]).to eq('se00')
        expect(result[:msg]).to include('HTTP 503')
      end
    end

    context 'when network errors occur' do
      it 'handles timeout errors' do
        stub_request(:post, api_url)
          .to_timeout

        result = described_class.send_to_central_hub(klass, template, metadata, origin)

        expect(result[:mc]).to eq('se00')
        expect(result[:msg]).to include('Connection failure')
        expect(result[:data]).to eq({})
      end

      it 'handles connection refused errors' do
        stub_request(:post, api_url)
          .to_raise(Errno::ECONNREFUSED)

        result = described_class.send_to_central_hub(klass, template, metadata, origin)

        expect(result[:mc]).to eq('se00')
        expect(result[:msg]).to include('Connection failure')
      end

      it 'handles socket errors' do
        stub_request(:post, api_url)
          .to_raise(SocketError.new('getaddrinfo: Name or service not known'))

        result = described_class.send_to_central_hub(klass, template, metadata, origin)

        expect(result[:mc]).to eq('se00')
        expect(result[:msg]).to include('Connection failure')
      end

      it 'handles generic standard errors' do
        stub_request(:post, api_url)
          .to_raise(StandardError.new('Unexpected error'))

        result = described_class.send_to_central_hub(klass, template, metadata, origin)

        expect(result[:mc]).to eq('se00')
        expect(result[:msg]).to include('Unexpected error')
      end
    end

    context 'with different template classes' do
      it 'works with SegmentKlass' do
        stub_request(:post, api_url)
          .with(body: hash_including('template_klass' => 'SegmentKlass'))
          .to_return(status: 200, body: { id: 789 }.to_json)

        result = described_class.send_to_central_hub('SegmentKlass', template, metadata, origin)

        expect(result[:mc]).to eq('ss00')
        expect(result[:data][:id]).to eq(789)
      end

      it 'works with DatasetKlass' do
        stub_request(:post, api_url)
          .with(body: hash_including('template_klass' => 'DatasetKlass'))
          .to_return(status: 201, body: { id: 999 }.to_json)

        result = described_class.send_to_central_hub('DatasetKlass', template, metadata, origin)

        expect(result[:mc]).to eq('ss00')
        expect(result[:data][:id]).to eq(999)
      end
    end

    context 'with complex template data' do
      it 'handles large template objects' do
        large_template = {
          name: 'Complex Template',
          properties: {
            layers: Array.new(10) { |i| { layer: i, fields: Array.new(5) { |j| { field: j } } } }
          }
        }

        stub_request(:post, api_url)
          .to_return(status: 200, body: { id: 111 }.to_json)

        result = described_class.send_to_central_hub(klass, large_template, metadata, origin)

        expect(result[:mc]).to eq('ss00')
      end

      it 'handles special characters in metadata' do
        special_metadata = metadata.merge(
          submission: metadata[:submission].merge(
            message: "Special chars: <>&\"'\n\t"
          )
        )

        stub_request(:post, api_url)
          .to_return(status: 200, body: { id: 222 }.to_json)

        result = described_class.send_to_central_hub(klass, template, special_metadata, origin)

        expect(result[:mc]).to eq('ss00')
      end
    end
  end
end
