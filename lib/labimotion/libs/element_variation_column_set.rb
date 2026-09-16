# frozen_string_literal: true

require 'labimotion/utils/units'

module Labimotion
  ## ElementVariationColumnSet
  # Resolves the ordered set of columns for an element's variations grid.
  #
  # Both ExportElementVariations and ImportElementVariations go through this
  # class, so a workbook written by the exporter is always readable by the
  # importer. The ordering mirrors the React grid
  # (GenericElementVariationsColumnDefs.js): driven by the stored layout when
  # there is one, otherwise inferred from the variation data itself -- the same
  # fallback the frontend applies when it loads a record with an empty layout.
  class ElementVariationColumnSet
    UUID_KEY = '__uuid'
    NAME_KEY = '__variation'
    ANALYSES_FIELD = '__analyses__'

    # Mirrors Labimotion::Prop::LAYERS / ::FIELDS. Held locally because
    # requiring `labimotion/utils/prop` here would race the gem's autoload.
    LAYERS = 'layers'
    FIELDS = 'fields'

    GROUPS = %w[properties metadata segments].freeze
    GROUP_LABELS = {
      'properties' => 'Properties',
      'metadata' => 'Metadata',
      'segments' => 'Segments'
    }.freeze
    METADATA_FIELDS = %w[notes analyses group].freeze
    METADATA_LABELS = {
      'notes' => 'Notes',
      'analyses' => 'Analyses (IDs)',
      'group' => 'Group'
    }.freeze

    # Mirrors the field-type allowlist chem-generic-ui applies when it offers
    # columns. `select-multi` deliberately has no Labimotion::FieldType constant.
    COLUMN_FIELD_TYPES = %w[
      integer number select system-defined text date datetime select-multi
    ].freeze

    # `label` is the leaf header only. `group` / `sub_group` carry the two header
    # levels above it, so the exporter can rebuild the grid's banded header.
    # `sub_group_key` disambiguates two sub-groups that happen to share a label.
    Column = Struct.new(
      :key, :label, :unit, :kind, :field_type, :group, :sub_group, :sub_group_key,
      keyword_init: true
    )

    class << self
      def build(element, variation, segment_klasses: nil)
        new(element, variation, segment_klasses: segment_klasses).columns
      end

      def encode_property_key(layer_key, field_key)
        "layer#{layer_key}field#{field_key}"
      end

      def decode_property_key(key)
        match = key.to_s.match(/\Alayer(.+?)field(.+)\z/m)
        return nil unless match

        { layer_key: match[1], field_key: match[2] }
      end

      def analyses_property_key?(key)
        decoded = decode_property_key(key)
        !decoded.nil? && decoded[:field_key] == ANALYSES_FIELD
      end
    end

    def initialize(element, variation, segment_klasses: nil)
      @element = element
      @variations = variation.respond_to?(:variations_hash) ? variation.variations_hash : {}
      @layout = variation.respond_to?(:layout_hash) ? variation.layout_hash : {}
      @segment_klasses = segment_klasses
    end

    attr_reader :element, :variations, :layout

    def columns
      @columns ||= begin
        cols = [
          Column.new(key: UUID_KEY, label: 'Row ID', unit: '', kind: :uuid, field_type: nil),
          Column.new(key: NAME_KEY, label: 'Variation', unit: '', kind: :name, field_type: nil)
        ]
        group_order.each { |group| cols.concat(columns_for_group(group)) }
        cols
      end
    end

    def lookup(key)
      @lookup ||= columns.each_with_object({}) { |col, acc| acc[col.key] = col }
      @lookup[key]
    end

    # Variation rows in the grid's display order: layout rowOrder first, then
    # anything the layout does not mention, uuid-sorted (as `sortedRows` does).
    def rows
      seen = {}
      ordered = []
      Array(layout['rowOrder']).each do |uuid|
        row = variations[uuid.to_s]
        next unless row.is_a?(Hash)

        ordered << row
        seen[uuid.to_s] = true
      end
      remaining = variations.reject { |uuid, row| seen[uuid.to_s] || !row.is_a?(Hash) }
      ordered + remaining.values.sort_by { |row| row['uuid'].to_s }
    end

    def segment_klasses
      @segment_klasses ||= Labimotion::SegmentKlass.where(element_klass_id: element.element_klass_id).to_a
    end

    def segment_klass(klass_id)
      @segment_klass_index ||= segment_klasses.each_with_object({}) do |klass, acc|
        acc[klass.id.to_s] = klass
      end
      @segment_klass_index[klass_id.to_s]
    end

    private

    def columns_for_group(group)
      case group
      when 'properties' then property_columns
      when 'metadata' then metadata_columns
      when 'segments' then segment_columns
      else []
      end
    end

    def group_order
      stored = Array(layout['groupOrder']).select { |group| GROUPS.include?(group) }
      stored + (GROUPS - stored)
    end

    # ---- properties -------------------------------------------------------

    # Grouped by layer, each layer's fields followed by its "Link Analyses"
    # column -- the leaf order buildColumnDefs produces.
    def property_columns
      analysis_layers = selected_analysis_layers
      property_layers.flat_map do |layer_key, layer|
        next layer[:columns] unless analysis_layers.include?(layer_key)

        layer[:columns] + [analyses_layer_column(layer_key, layer[:label])]
      end
    end

    # layer_key => { label:, columns: }, in the grid's layer order: layers
    # holding a selected field first, then layers selected for analyses only.
    def property_layers
      layers = {}
      selected_property_keys.each do |property_key|
        option = property_options[property_key]
        next if option.nil?

        layer = ensure_property_layer(layers, option['layerKey'], option['layerLabel'])
        layer[:columns] << property_column(property_key, option, layer[:label])
      end
      selected_analysis_layers.each do |layer_key|
        ensure_property_layer(layers, layer_key, layer_labels[layer_key.to_s])
      end
      layers
    end

    def ensure_property_layer(layers, layer_key, layer_label)
      key = layer_key.to_s
      layers[key] ||= { label: presence(layer_label) || key, columns: [] }
    end

    def property_column(property_key, option, layer_label)
      unit = unit_for("prop:#{property_key}", option, inferred_property_unit(property_key))
      Column.new(
        key: "prop:#{property_key}",
        label: with_unit(option['fieldLabel'], unit),
        unit: unit,
        kind: :property,
        field_type: option['type'],
        group: GROUP_LABELS['properties'],
        sub_group: layer_label,
        sub_group_key: option['layerKey'].to_s
      )
    end

    def analyses_layer_column(layer_key, layer_label)
      Column.new(
        key: "prop:#{self.class.encode_property_key(layer_key, ANALYSES_FIELD)}",
        label: 'Link Analyses (IDs)',
        unit: '',
        kind: :property,
        field_type: ANALYSES_FIELD,
        group: GROUP_LABELS['properties'],
        sub_group: layer_label,
        sub_group_key: layer_key.to_s
      )
    end

    def selected_property_keys
      stored = Array(layout['selectedPropertyKeys']).map(&:to_s)
      return stored unless stored.empty?

      keys_from_data.reject { |key| self.class.analyses_property_key?(key) }
    end

    def selected_analysis_layers
      stored = Array(layout['selectedAnalysisLayers']).map(&:to_s)
      return stored unless stored.empty?

      keys_from_data.filter_map do |key|
        decoded = self.class.decode_property_key(key)
        decoded[:layer_key] if decoded && decoded[:field_key] == ANALYSES_FIELD
      end.uniq
    end

    def keys_from_data
      @keys_from_data ||= variations.values.flat_map do |row|
        row.is_a?(Hash) ? (row['properties'] || {}).keys : []
      end.uniq
    end

    def inferred_property_unit(key)
      variations.each_value do |row|
        next unless row.is_a?(Hash)

        cell = (row['properties'] || {})[key]
        return cell['unit'].to_s if cell.is_a?(Hash) && !cell['unit'].to_s.empty?
      end
      nil
    end

    # ---- metadata ---------------------------------------------------------

    # Metadata leaves hang straight off the group, as they do in the grid: no
    # sub_group, so the exporter spans their header down a row.
    def metadata_columns
      selected_metadata_keys.map do |field|
        Column.new(
          key: "meta:#{field}",
          label: METADATA_LABELS[field] || field,
          unit: '',
          kind: :metadata,
          field_type: field,
          group: GROUP_LABELS['metadata']
        )
      end
    end

    def selected_metadata_keys
      stored = Array(layout['selectedMetadataKeys']).map(&:to_s)
      stored.empty? ? METADATA_FIELDS.dup : stored
    end

    # ---- segments ---------------------------------------------------------

    def segment_columns
      selected_segment_ids.flat_map do |klass_id|
        klass = segment_klass(klass_id)
        segment_label = klass ? (klass.label || "Segment #{klass_id}") : "Segment #{klass_id}"
        options = segment_field_options(klass_id)

        selected_segment_fields(klass_id).filter_map do |field_key|
          option = options[field_key]
          next if option.nil?

          unit = unit_for("seg:#{klass_id}:#{field_key}", option, nil)
          Column.new(
            key: "seg:#{klass_id}:#{field_key}",
            label: with_unit(option['fieldLabel'], unit),
            unit: unit,
            kind: :segment,
            field_type: option['type'],
            group: GROUP_LABELS['segments'],
            sub_group: segment_label,
            sub_group_key: klass_id.to_s
          )
        end
      end
    end

    def selected_segment_ids
      stored = Array(layout['selectedSegmentIds']).map(&:to_s)
      return stored unless stored.empty?

      variations.values.flat_map do |row|
        row.is_a?(Hash) ? (row['segments'] || {}).keys.map(&:to_s) : []
      end.uniq
    end

    def selected_segment_fields(klass_id)
      stored = layout['selectedSegmentFields']
      if stored.is_a?(Hash)
        keys = stored[klass_id.to_s] || stored[klass_id.to_i]
        return Array(keys).map(&:to_s) unless keys.nil?
      end

      variations.values.flat_map do |row|
        next [] unless row.is_a?(Hash)

        (row.dig('segments', klass_id.to_s) || {}).keys.map(&:to_s)
      end.uniq
    end

    def segment_field_options(klass_id)
      @segment_field_options ||= {}
      @segment_field_options[klass_id.to_s] ||= begin
        klass = segment_klass(klass_id)
        options = {}
        each_layer_field(release_of(klass)) do |_layer_key, _layer_label, field|
          options[field['field'].to_s] ||= field_option(field)
        end
        options
      end
    end

    # ---- shared schema walking -------------------------------------------

    def property_options
      @property_options ||= begin
        options = {}
        each_layer_field(element_klass_release) do |layer_key, layer_label, field|
          key = self.class.encode_property_key(layer_key, field['field'])
          options[key] = field_option(field).merge('layerKey' => layer_key, 'layerLabel' => layer_label)
        end
        options
      end
    end

    def layer_labels
      @layer_labels ||= begin
        layers = element_klass_release[LAYERS] || {}
        layers.each_with_object({}) do |(layer_key, layer), acc|
          acc[layer_key.to_s] = layer['label'] || layer_key.to_s
        end
      end
    end

    def element_klass_release
      @element_klass_release ||= begin
        klass = element.respond_to?(:element_klass) ? element.element_klass : nil
        release = release_of(klass)
        release.empty? ? release_of(element) : release
      end
    end

    def release_of(record)
      return {} if record.nil? || !record.respond_to?(:properties_release)

      release = record.properties_release
      release.is_a?(Hash) ? release : {}
    end

    def each_layer_field(release)
      layers = release[LAYERS] || {}
      layers.each do |layer_key, layer|
        next unless layer.is_a?(Hash)

        layer_label = layer['label'] || layer_key.to_s
        Array(layer[FIELDS]).each do |field|
          next unless field.is_a?(Hash) && !field['field'].to_s.empty?
          next unless COLUMN_FIELD_TYPES.include?(field['type'].to_s)

          yield(layer_key.to_s, layer_label, field)
        end
      end
    end

    def field_option(field)
      label = field['label'].to_s.empty? ? field['field'].to_s : field['label'].to_s
      {
        'fieldKey' => field['field'].to_s,
        'fieldLabel' => label,
        'type' => field['type'].to_s,
        'defaultUnit' => default_unit(field)
      }
    end

    # ---- units ------------------------------------------------------------

    # The grid stores unit *keys* (`C`, `mm_s2`), never the display labels --
    # some of which carry HTML (`mm/s<sup>2</sup>`). Keep the key: it is what a
    # round-trip must preserve.
    def field_units(field)
      quantity = field['option_layers'] || field['generic_quantity']
      return [] if quantity.to_s.empty?

      config = Labimotion::Units::FIELDS.find { |entry| entry[:field] == quantity }
      return [] unless config

      Array(config[:units]).filter_map { |unit| unit[:key]&.to_s }
    end

    def default_unit(field)
      units = field_units(field)
      return '' if units.empty?

      value_system = field['value_system'].to_s
      value_system.empty? ? units.first : value_system
    end

    def unit_for(column_key, option, inferred)
      stored = column_units[column_key]
      return stored.to_s unless stored.to_s.empty?
      return inferred.to_s unless inferred.to_s.empty?

      option['defaultUnit'].to_s
    end

    def column_units
      @column_units ||= layout['columnUnits'].is_a?(Hash) ? layout['columnUnits'] : {}
    end

    def with_unit(label, unit)
      unit.to_s.empty? ? label : "#{label} [#{unit}]"
    end

    def presence(value)
      value.to_s.empty? ? nil : value.to_s
    end
  end
end
