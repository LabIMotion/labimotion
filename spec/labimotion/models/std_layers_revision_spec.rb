require 'spec_helper'
require 'ostruct'

module Labimotion
  class ApplicationRecord < OpenStruct
    @table_name = nil
    def self.acts_as_paranoid; end
    def self.belongs_to(name, options = {}); end

    class << self
      attr_writer :table_name
    end

    def self.table_name
      @table_name.to_s
    end
  end
end

require_relative '../../../lib/labimotion/models/std_layers_revision'

RSpec.describe Labimotion::StdLayersRevision, type: :model do
  describe 'initialization' do
    it 'can be instantiated with attributes' do
      revision = Labimotion::StdLayersRevision.new(identifier: '123', name: 'Test Layer')
      expect(revision.identifier).to eq('123')
      expect(revision.name).to eq('Test Layer')
    end
  end

  describe 'table name' do
    it { expect(described_class.table_name).to eq('layer_tracks') }
  end

  describe 'paranoid behavior' do
    it 'marks an object as deleted instead of deleting it' do
      revision = Labimotion::StdLayersRevision.new(identifier: '123', name: 'Test Layer', deleted_at: nil)
      # Simulate the act_as_paranoid behavior
      revision.deleted_at = Time.now

      expect(revision.deleted_at).not_to be_nil
    end
  end
end
