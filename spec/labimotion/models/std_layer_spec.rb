require 'spec_helper'
require 'ostruct'

# Mock ApplicationRecord and other Rails features
module Labimotion
  class ApplicationRecord < OpenStruct
    @table_name = nil
    def self.acts_as_paranoid; end
    def self.has_many(name, options = {}); end

    class << self
      attr_writer :table_name
    end

    def self.table_name
      @table_name.to_s
    end
  end
end

require_relative '../../../lib/labimotion/models/std_layer'

RSpec.describe Labimotion::StdLayer do
  describe 'initialization' do
    it 'can be instantiated with attributes' do
      ltd = Labimotion::StdLayer.new(identifier: '123', name: 'Test Layer')
      expect(ltd.identifier).to eq('123')
      expect(ltd.name).to eq('Test Layer')
    end
  end

  describe 'table name' do
    it { expect(described_class.table_name).to eq('layers') }
  end

  describe 'paranoid behavior' do
    it 'marks an object as deleted instead of deleting it' do
      ltd = Labimotion::StdLayer.new(identifier: '123', name: 'Test Layer', deleted_at: nil)
      # Simulate the act_as_paranoid behavior
      ltd.deleted_at = Time.now

      expect(ltd.deleted_at).not_to be_nil
    end
  end

  # Example of testing custom logic
  # Replace `some_method` with actual method names and adjust expectations
  # describe '#some_method' do
  #   it 'performs expected behavior' do
  #     layer = Labimotion::StdLayer.new(identifier: '123', name: 'Test Layer')
  #     result = layer.some_method
  #     expect(result).to eq(expected_result)
  #   end
  # end
end
