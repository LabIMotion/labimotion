# frozen_string_literal: true

require 'caxlsx'

module Labimotion
  ## ElementVariationHeader
  # Turns an ordered column set into the banded header the React grid draws:
  #
  #   row 1  group      Properties                  | Metadata        | Segments
  #   row 2  sub-group  Conditions                  | Notes | Group   | My Segment
  #   row 3  leaf       Temperature [C] | Solvent   |       |         | Mass [g]
  #
  # Adjacent columns sharing a header are merged across, and a header with no
  # level beneath it -- the identity columns, and the metadata leaves, which hang
  # straight off their group -- is merged down to the leaf row. That is exactly
  # what ag-grid renders for the same columns.
  #
  # `rows` are the three cell arrays; `merges` the ranges to hand to Axlsx.
  class ElementVariationHeader
    ROWS = 3

    def initialize(columns)
      @columns = columns
    end

    attr_reader :columns

    def rows
      plan[:rows]
    end

    def merges
      plan[:merges]
    end

    private

    def plan
      @plan ||= build
    end

    def build
      @rows = Array.new(ROWS) { Array.new(columns.length, '') }
      @merges = []

      runs(columns.map(&:group)).each { |run| place_group(run) }
      runs(columns.map { |column| sub_group_key(column) }).each { |run| place_sub_group(run) }

      { rows: @rows, merges: @merges }
    end

    def place_group(run)
      # No group at all: an identity column, spanning the whole header.
      return span_down(run, 0) if blank?(run[:key])

      span_across(run, 0, run[:key])
    end

    def place_sub_group(run)
      return if run[:key].nil?

      sub_group = columns[run[:first]].sub_group
      # No sub-group: a metadata leaf, spanning the rows below its group.
      return span_down(run, 1) if blank?(sub_group)

      span_across(run, 1, sub_group)
      fill(run, 2)
    end

    # One cell per column, each merged down to the leaf row.
    def span_down(run, row)
      fill(run, row)
      column_range(run).each { |index| merge(index, row, index, ROWS - 1) }
    end

    # A single cell carrying `text` across the whole run.
    def span_across(run, row, text)
      @rows[row][run[:first]] = text
      merge(run[:first], row, run[:last], row) unless run[:last] == run[:first]
    end

    def fill(run, row)
      column_range(run).each { |index| @rows[row][index] = columns[index].label }
    end

    def column_range(run)
      (run[:first]..run[:last])
    end

    def merge(from_column, from_row, to_column, to_row)
      @merges << [cell_ref(from_column, from_row), cell_ref(to_column, to_row)]
    end

    def cell_ref(column_index, row_index)
      "#{Axlsx.col_ref(column_index)}#{row_index + 1}"
    end

    # Keyed on the sub-group *key*, not its label: two layers may share a label.
    def sub_group_key(column)
      blank?(column.group) ? nil : [column.group, column.sub_group_key]
    end

    # Contiguous columns sharing a header key.
    def runs(keys)
      keys.each_with_index.with_object([]) do |(key, index), acc|
        last = acc.last
        if last && last[:key] == key
          last[:last] = index
        else
          acc << { key: key, first: index, last: index }
        end
      end
    end

    def blank?(value)
      value.to_s.empty?
    end
  end
end
