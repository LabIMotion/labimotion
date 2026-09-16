# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/labimotion/libs/element_variation_header'
require_relative '../../../lib/labimotion/libs/element_variation_column_set'

RSpec.describe Labimotion::ElementVariationHeader do
  def column(label, group: nil, sub_group: nil, sub_group_key: nil)
    Labimotion::ElementVariationColumnSet::Column.new(
      key: label, label: label, unit: '', kind: :property,
      group: group, sub_group: sub_group, sub_group_key: sub_group_key || sub_group
    )
  end

  subject(:header) { described_class.new(columns) }

  describe 'a column with no group' do
    let(:columns) { [column('Row ID')] }

    it 'labels the group row and spans the whole header' do
      expect(header.rows).to eq([['Row ID'], [''], ['']])
      expect(header.merges).to eq([%w[A1 A3]])
    end
  end

  describe 'a group whose leaves have no sub-group' do
    let(:columns) { [column('Notes', group: 'Metadata'), column('Group', group: 'Metadata')] }

    it 'merges the group across and each leaf down' do
      expect(header.rows).to eq([['Metadata', ''], %w[Notes Group], ['', '']])
      expect(header.merges).to eq([%w[A1 B1], %w[A2 A3], %w[B2 B3]])
    end
  end

  describe 'a group of sub-groups' do
    let(:columns) do
      [
        column('Temperature', group: 'Properties', sub_group: 'Conditions'),
        column('Solvent', group: 'Properties', sub_group: 'Conditions'),
        column('Yield', group: 'Properties', sub_group: 'Workup')
      ]
    end

    it 'merges the group across all of them and each sub-group across its own' do
      expect(header.rows).to eq(
        [['Properties', '', ''], ['Conditions', '', 'Workup'], %w[Temperature Solvent Yield]]
      )
      expect(header.merges).to eq([%w[A1 C1], %w[A2 B2]])
    end
  end

  # Two layers may carry the same label; merging them into one banner would
  # misreport which columns belong to which layer.
  describe 'adjacent sub-groups that share a label' do
    let(:columns) do
      [
        column('Mass', group: 'Segments', sub_group: 'Sample', sub_group_key: '11'),
        column('Volume', group: 'Segments', sub_group: 'Sample', sub_group_key: '12')
      ]
    end

    it 'keeps them apart' do
      expect(header.rows[1]).to eq(%w[Sample Sample])
      expect(header.merges).to eq([%w[A1 B1]])
    end
  end

  describe 'a single-column group' do
    let(:columns) { [column('Mass', group: 'Segments', sub_group: 'My Segment')] }

    it 'writes the headers without merging anything' do
      expect(header.rows).to eq([['Segments'], ['My Segment'], ['Mass']])
      expect(header.merges).to be_empty
    end
  end

  describe 'the full column set shape' do
    let(:columns) do
      [
        column('Row ID'),
        column('Variation'),
        column('Temperature [C]', group: 'Properties', sub_group: 'Conditions'),
        column('Link Analyses (IDs)', group: 'Properties', sub_group: 'Conditions'),
        column('Notes', group: 'Metadata'),
        column('Mass [g]', group: 'Segments', sub_group: 'My Segment')
      ]
    end

    it 'reserves a cell per column on every header row' do
      expect(header.rows.map(&:length)).to eq([6, 6, 6])
    end

    it 'merges each header over exactly the columns it covers' do
      expect(header.merges).to eq(
        [%w[A1 A3], %w[B1 B3], %w[C1 D1], %w[C2 D2], %w[E2 E3]]
      )
    end
  end
end
