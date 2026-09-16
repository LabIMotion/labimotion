# frozen_string_literal: true

require 'spec_helper'
require 'zip'
require_relative '../../lib/labimotion/utils/mapper_utils'

RSpec.describe Labimotion::MapperUtils do
  describe '.load_config' do
    context 'with valid JSON' do
      let(:valid_json) { '{"sourceMap": {"sourceSelector": ["test"], "parameters": {"param1": "value1"}}}' }

      it 'successfully parses JSON' do
        result = described_class.load_config(valid_json)
        expect(result).to be_a(Hash)
        expect(result['sourceMap']).to be_present
      end
    end

    context 'with invalid JSON' do
      let(:invalid_json) { '{invalid_json' }

      it 'returns nil and logs error' do
        expect(Rails.logger).to receive(:error).with(/Error parsing JSON/)
        expect(described_class.load_config(invalid_json)).to be_nil
      end
    end
  end

  describe '.load_brucker_config' do
    let(:valid_config) do
      {
        'sourceMap' => {
          'sourceSelector' => ['test'],
          'parameters' => { 'param1' => 'value1' }
        }
      }.to_json
    end

    before do
      allow(File).to receive(:read).with(Labimotion::Constants::Mapper::NMR_CONFIG).and_return(valid_config)
    end

    it 'successfully loads config' do
      result = described_class.load_brucker_config
      expect(result).to be_a(Hash)
      expect(result.dig('sourceMap', 'sourceSelector')).to eq(['test'])
    end

    context 'with invalid config' do
      before do
        allow(File).to receive(:read).with(Labimotion::Constants::Mapper::NMR_CONFIG)
                                     .and_return('{"sourceMap": {}}')
      end

      it 'returns nil for missing required fields' do
        expect(described_class.load_brucker_config).to be_nil
      end
    end
  end

  describe '.extract_parameters' do
    let(:file_content) { "## $DATE = 20210614\n## $TIME = 12.59\nother content" }
    let(:parameter_names) { %w[DATE TIME] }

    it 'extracts parameters correctly' do
      result = described_class.extract_parameters(file_content, parameter_names)
      expect(result).to eq('DATE' => '20210614', 'TIME' => '12.59')
    end

    context 'with nil content' do
      it 'returns empty hash' do
        result = described_class.extract_parameters(nil, parameter_names)
        expect(result).to be_nil
      end
    end

    context 'with invalid content' do
      it 'returns empty hash for nil content' do
        result = described_class.extract_parameters('', parameter_names)
        expect(result).to be_nil
      end
    end
  end

  describe '.extract_array_parameters' do
    # Single-quoted heredocs so the literal '##$D' is not mangled by Ruby's
    # '#$name' global-variable interpolation.
    let(:file_content) do
      <<~'ACQUS'
        ##$DATE= 1700000000
        ##$D= (0..63)
        0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.0002 0 0 0 0 0 0 0 0 0 0 0 0 0
        ##$DE= 6.5
      ACQUS
    end
    let(:array_parameters) { { 'D1' => { 'name' => 'D', 'index' => 1 } } }

    it 'extracts the indexed value from a Bruker array parameter' do
      result = described_class.extract_array_parameters(file_content, array_parameters)
      expect(result).to eq('D1' => '1')
    end

    it 'reads the value at the requested index' do
      result = described_class.extract_array_parameters(file_content, 'D16' => { 'name' => 'D', 'index' => 16 })
      expect(result).to eq('D16' => '0.0002')
    end

    it 'returns empty hash when no array config is given' do
      expect(described_class.extract_array_parameters(file_content, nil)).to eq({})
    end

    it 'returns empty hash when the array header is absent' do
      result = described_class.extract_array_parameters("##$NS= 16\n", array_parameters)
      expect(result).to eq({})
    end

    it 'concatenates values spanning multiple lines' do
      content = <<~'ACQUS'
        ##$D= (0..63)
        0 1
        0 0 0.0002
        ##$NEXT= 1
      ACQUS
      result = described_class.extract_array_parameters(content, 'D4' => { 'name' => 'D', 'index' => 4 })
      expect(result).to eq('D4' => '0.0002')
    end
  end

  describe '.extract_data_from_zip' do
    let(:zip_file_path) { File.join(Dir.pwd, 'spec/fixtures/test.zip') }
    let(:source_map) do
      {
        'sourceSelector' => ['source1'],
        'source1' => {
          'file' => 'test.txt',
          'parameters' => %w[PARAM1 PARAM2]
        }
      }
    end

    before(:all) do
      FileUtils.mkdir_p('spec/fixtures')
    end

    before do
      Zip::File.open(zip_file_path, Zip::File::CREATE) do |zipfile|
        zipfile.get_output_stream('test.txt') do |f|
          f.write "## $PARAM1 = value1\n## $PARAM2 = value2"
        end
      end
    end

    after do
      FileUtils.rm_f(zip_file_path)
    end

    after(:all) do
      FileUtils.rm_rf('spec/fixtures')
    end

    it 'processes zip file and extracts parameters' do
      result = described_class.extract_data_from_zip(zip_file_path, source_map)
      expect(result).to include(
        is_bagit: false,
        metadata: include('PARAM1' => 'value1', 'PARAM2' => 'value2')
      )
    end

    it 'returns nil for invalid zip file' do
      expect(described_class.extract_data_from_zip('invalid.zip', source_map)).to be_nil
    end
  end

  describe 'D1 source precedence (parm.txt > acqus ##$D array)' do
    let(:zip_file_path) { File.join(Dir.pwd, 'spec/fixtures/precedence.zip') }
    let(:source_map) do
      {
        'sourceSelector' => %w[parm acqus],
        'parm' => { 'file' => 'pdata/1/parm.txt', 'parameters' => ['D1'] },
        'acqus' => { 'file' => 'acqus', 'arrayParameters' => { 'D1' => { 'name' => 'D', 'index' => 1 } } }
      }
    end
    # Single-quoted heredoc: '##$D' must not be interpolated as the global '$D'.
    let(:acqus_content) do
      <<~'ACQUS'
        ##$D= (0..63)
        0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.0002 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
        0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
      ACQUS
    end

    before(:all) { FileUtils.mkdir_p('spec/fixtures') }
    after { FileUtils.rm_f(zip_file_path) }
    after(:all) { FileUtils.rm_rf('spec/fixtures') }

    def build_zip(parm_content)
      Zip::File.open(zip_file_path, Zip::File::CREATE) do |zipfile|
        zipfile.get_output_stream('pdata/1/parm.txt') { |f| f.write(parm_content) }
        zipfile.get_output_stream('acqus') { |f| f.write(acqus_content) }
      end
    end

    it 'uses parm.txt D1 when present (acqus ##$D is only a fallback)' do
      build_zip("D1   5   sec\n")
      result = described_class.extract_data_from_zip(zip_file_path, source_map)
      expect(result[:metadata]).to include('D1' => '5')
    end

    it 'falls back to acqus ##$D index 1 when parm.txt has no D1' do
      build_zip("NS   16\n")
      result = described_class.extract_data_from_zip(zip_file_path, source_map)
      expect(result[:metadata]).to include('D1' => '1')
    end
  end
end
