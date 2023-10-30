# frozen_string_literal: true

require 'labimotion/entities/application_entity'
module Labimotion
  ## Segment entity
  class SegmentEntity < ApplicationEntity
    expose :id, :segment_klass_id, :element_type, :element_id, :properties, :properties_release, :uuid, :klass_uuid, :klass_label

    def klass_label
      object.segment_klass.label
    end

    def properties # rubocop:disable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength
      return unless object.respond_to?(:properties)

      return if object&.properties.dig('layers').blank?

      object&.properties['layers'].each_key do |key|  # rubocop:disable Metrics/BlockLength
        next if object&.properties.dig('layers', key, 'fields').blank?

        field_sample_molecules = object&.properties['layers'][key]['fields'].select { |ss| ss['type'] == 'drag_molecule' }
        field_sample_molecules.each do |field|
          idx = object&.properties['layers'][key]['fields'].index(field)
          sid = field.dig('value', 'el_id')
          next if sid.blank?

          el = Molecule.find_by(id: sid)
          next if el.blank?

          next if object&.properties.dig('layers', key, 'fields', idx, 'value').blank?

          object&.properties['layers'][key]['fields'][idx]['value']['el_svg'] = File.join('/images', 'molecules', el.molecule_svg_file)
        end

        field_tables = object.properties['layers'][key]['fields'].select { |ss| ss['type'] == 'table' }
        field_tables.each do |field|
          next unless field['sub_values'].present? && field['sub_fields'].present?

          field_table_molecules = field['sub_fields'].select { |ss| ss['type'] == 'drag_molecule' }
          next if field_table_molecules.blank?

          col_ids = field_table_molecules.map { |x| x.values[0] }
          col_ids.each do |col_id|
            field['sub_values'].each do |sub_value|
              next unless sub_value[col_id].present? && sub_value[col_id]['value'].present? && sub_value[col_id]['value']['el_id'].present?

              find_mol = Molecule.find_by(id: sub_value[col_id]['value']['el_id'])
              next if find_mol.blank?

              sub_value[col_id]['value']['el_svg'] = File.join('/images', 'molecules', find_mol.molecule_svg_file)
              sub_value[col_id]['value']['el_inchikey'] = find_mol.inchikey
              sub_value[col_id]['value']['el_smiles'] = find_mol.cano_smiles
              sub_value[col_id]['value']['el_iupac'] = find_mol.iupac_name
              sub_value[col_id]['value']['el_molecular_weight'] = find_mol.molecular_weight
            end
          end
        end
      end
      object&.properties
    end
  end
end
