# frozen_string_literal: true

# Stand-ins for the ActiveRecord objects the element-variation exporter and
# importer touch. The gem's spec process has no ActiveRecord, so these expose
# just the surface those classes actually use.
module ElementVariationDoubles
  FakeAnalysis = Struct.new(:id, :name, :extended_metadata)

  class FakeKlass
    attr_reader :id, :name, :label, :properties_release

    def initialize(id:, name:, label:, properties_release:)
      @id = id
      @name = name
      @label = label
      @properties_release = properties_release
    end
  end

  class FakeElement
    attr_reader :id, :short_label, :name, :element_klass, :element_klass_id, :analyses, :properties_release
    attr_accessor :element_variation

    def initialize(id:, short_label:, name:, element_klass:, analyses: [], element_variation: nil)
      @id = id
      @short_label = short_label
      @name = name
      @element_klass = element_klass
      @element_klass_id = element_klass.id
      @analyses = analyses
      @element_variation = element_variation
      @properties_release = {}
    end
  end

  # Mimics Labimotion::ElementVariation closely enough for the importer:
  # variations_hash / layout_hash readers, writers, save!, and the
  # `class.column_names` probe it uses before touching `layout`.
  class FakeRecord
    def self.column_names
      %w[id element_id variations layout]
    end

    attr_accessor :variations, :layout
    attr_reader :element_id, :save_count

    def initialize(element_id:, variations: {}, layout: {})
      @element_id = element_id
      @variations = variations
      @layout = layout
      @save_count = 0
    end

    def variations_hash
      variations.is_a?(Hash) ? variations : {}
    end

    def layout_hash
      layout.is_a?(Hash) ? layout : {}
    end

    def save!
      @save_count += 1
      true
    end
  end

  # A two-layer element klass: one plain text field, one unit-bearing
  # system-defined field, one select-multi, one integer.
  def self.element_klass
    FakeKlass.new(
      id: 7,
      name: 'my_element',
      label: 'My Element',
      properties_release: {
        'layers' => {
          'conditions' => {
            'label' => 'Conditions',
            'fields' => [
              { 'field' => 'temperature', 'label' => 'Temperature', 'type' => 'system-defined',
                'option_layers' => 'temperature', 'value_system' => 'C' },
              { 'field' => 'solvent', 'label' => 'Solvent', 'type' => 'text' },
              { 'field' => 'tags', 'label' => 'Tags', 'type' => 'select-multi',
                'option_layers' => 'tag_options' },
              { 'field' => 'cycles', 'label' => 'Cycles', 'type' => 'integer' },
              { 'field' => 'ignored', 'label' => 'Ignored', 'type' => 'table' },
            ],
          },
        },
        'select_options' => {
          'tag_options' => { 'options' => [{ 'key' => 'a', 'label' => 'A' }, { 'key' => 'b', 'label' => 'B' }] },
        },
      },
    )
  end

  # Two layers, so specs can pin how a layer's columns are kept together.
  def self.two_layer_element_klass
    FakeKlass.new(
      id: 8,
      name: 'my_element',
      label: 'My Element',
      properties_release: {
        'layers' => {
          'conditions' => {
            'label' => 'Conditions',
            'fields' => [{ 'field' => 'solvent', 'label' => 'Solvent', 'type' => 'text' }],
          },
          'workup' => {
            'label' => 'Workup',
            'fields' => [{ 'field' => 'yield', 'label' => 'Yield', 'type' => 'number' }],
          },
        },
      },
    )
  end

  def self.segment_klass
    FakeKlass.new(
      id: 12,
      name: 'my_segment',
      label: 'My Segment',
      properties_release: {
        'layers' => {
          'physical' => {
            'label' => 'Physical',
            'fields' => [
              { 'field' => 'mass', 'label' => 'Mass', 'type' => 'number',
                'option_layers' => 'mass', 'value_system' => 'g' },
            ],
          },
        },
      },
    )
  end

  def self.element(analyses: default_analyses, element_variation: nil, element_klass: self.element_klass)
    FakeElement.new(id: 42, short_label: 'ME-1', name: 'My element', element_klass: element_klass,
                    analyses: analyses, element_variation: element_variation)
  end

  def self.default_analyses
    [
      FakeAnalysis.new(101, 'IR spectrum', { 'kind' => 'IR' }),
      FakeAnalysis.new(102, 'NMR', { 'kind' => 'NMR' }),
    ]
  end

  def self.variations
    {
      'uuid-b' => {
        'uuid' => 'uuid-b',
        'name' => 'ME-1-v2',
        'properties' => {
          'layerconditionsfieldtemperature' => { 'value' => 40, 'unit' => 'C' },
          'layerconditionsfieldsolvent' => { 'value' => 'water', 'unit' => '' },
          'layerconditionsfieldtags' => { 'value' => %w[a b], 'unit' => '' },
          'layerconditionsfieldcycles' => { 'value' => 3, 'unit' => '' },
          'layerconditionsfield__analyses__' => { 'value' => [101], 'unit' => '' },
        },
        'metadata' => { 'notes' => 'second', 'analyses' => [102], 'group' => '1.2' },
        'segments' => { '12' => { 'mass' => 2.5 } },
      },
      'uuid-a' => {
        'uuid' => 'uuid-a',
        'name' => 'ME-1-v1',
        'properties' => {
          'layerconditionsfieldtemperature' => { 'value' => 20, 'unit' => 'C' },
          'layerconditionsfieldsolvent' => { 'value' => 'ethanol', 'unit' => '' },
          'layerconditionsfieldtags' => { 'value' => ['a'], 'unit' => '' },
          'layerconditionsfieldcycles' => { 'value' => 1, 'unit' => '' },
          'layerconditionsfield__analyses__' => { 'value' => [], 'unit' => '' },
        },
        'metadata' => { 'notes' => 'first', 'analyses' => [], 'group' => '1.1' },
        'segments' => { '12' => { 'mass' => 1.5 } },
      },
    }
  end

  def self.layout
    {
      'selectedPropertyKeys' => %w[
        layerconditionsfieldtemperature
        layerconditionsfieldsolvent
        layerconditionsfieldtags
        layerconditionsfieldcycles
      ],
      'selectedAnalysisLayers' => ['conditions'],
      'selectedMetadataKeys' => %w[notes analyses group],
      'selectedSegmentIds' => [12],
      'selectedSegmentFields' => { '12' => ['mass'] },
      'columnUnits' => { 'prop:layerconditionsfieldtemperature' => 'C' },
      'groupOrder' => %w[properties metadata segments],
      'rowOrder' => %w[uuid-a uuid-b],
    }
  end

  def self.record(variations: self.variations, layout: self.layout)
    FakeRecord.new(element_id: 42, variations: variations, layout: layout)
  end
end
