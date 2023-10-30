# frozen_string_literal: true

module Labimotion
  ## Import Utils
  class ImportUtils
    def self.proc_sample(layer, key, data, properties)
      field_samples = layer['fields'].select { |ss| ss['type'] == 'drag_sample' }
      field_samples.each do |field|
        idx = properties['layers'][key]['fields'].index(field)
        id = field["value"] && field["value"]["el_id"] unless idx.nil?

        # mol = Molecule.find_or_create_by_molfile(data.fetch('Molecule')[id]['molfile']) unless id.nil?
        # unless mol.nil?
        #   properties['layers'][key]['fields'][idx]['value']['el_id'] = mol.id
        #   properties['layers'][key]['fields'][idx]['value']['el_tip'] = "#{mol.inchikey}@@#{mol.cano_smiles}"
        #   properties['layers'][key]['fields'][idx]['value']['el_label'] = mol.iupac_name
        # end
      end
      properties
    rescue StandardError => e
      Rails.logger.error(e.backtrace)
      raise
    end

    def self.proc_molecule(layer, key, data, properties)
      field_molecules = layer['fields'].select { |ss| ss['type'] == 'drag_molecule' }
      field_molecules.each do |field|
        idx = properties['layers'][key]['fields'].index(field)
        id = field["value"] && field["value"]["el_id"] unless idx.nil?
        mol = Molecule.find_or_create_by_molfile(data.fetch('Molecule')[id]['molfile']) unless id.nil?
        unless mol.nil?
          properties['layers'][key]['fields'][idx]['value']['el_id'] = mol.id
          properties['layers'][key]['fields'][idx]['value']['el_tip'] = "#{mol.inchikey}@@#{mol.cano_smiles}"
          properties['layers'][key]['fields'][idx]['value']['el_label'] = mol.iupac_name
        end
      end
      properties
    rescue StandardError => e
      Rails.logger.error(e.backtrace)
      raise
    end

    def self.proc_table(layer, key, data, properties)
      field_tables = layer['fields'].select { |ss| ss['type'] == 'table' }
      field_tables&.each do |field|
        tidx = layer['fields'].index(field)
        next unless field['sub_values'].present? && field['sub_fields'].present?

        field_table_molecules = field['sub_fields'].select { |ss| ss['type'] == 'drag_molecule' }
        if field_table_molecules.present?
          col_ids = field_table_molecules.map { |x| x.values[0] }
          col_ids.each do |col_id|
            field['sub_values'].each_with_index do |sub_value, vdx|
              next unless sub_value[col_id].present? && sub_value[col_id]['value'].present? && sub_value[col_id]['value']['el_id'].present?

              svalue = sub_value[col_id]['value']
              next unless svalue['el_id'].present? && svalue['el_inchikey'].present?

              tmol = Molecule.find_or_create_by_molfile(data.fetch('Molecule')[svalue['el_id']]['molfile']) unless svalue['el_id'].nil?
              unless tmol.nil?
                properties['layers'][key]['fields'][tidx]['sub_values'][vdx][col_id]['value']['el_id'] = tmol.id
                properties['layers'][key]['fields'][tidx]['sub_values'][vdx][col_id]['value']['el_tip'] = "#{tmol.inchikey}@@#{tmol.cano_smiles}"
                properties['layers'][key]['fields'][tidx]['sub_values'][vdx][col_id]['value']['el_label'] = tmol.cano_smiles
                properties['layers'][key]['fields'][tidx]['sub_values'][vdx][col_id]['value']['el_smiles'] = tmol.cano_smiles
                properties['layers'][key]['fields'][tidx]['sub_values'][vdx][col_id]['value']['el_iupac'] = tmol.iupac_name
                properties['layers'][key]['fields'][tidx]['sub_values'][vdx][col_id]['value']['el_inchikey'] = tmol.inchikey
                properties['layers'][key]['fields'][tidx]['sub_values'][vdx][col_id]['value']['el_svg'] = File.join('/images', 'molecules', tmol.molecule_svg_file)
                properties['layers'][key]['fields'][tidx]['sub_values'][vdx][col_id]['value']['el_molecular_weight'] = tmol.molecular_weight
              end
            end
          end
        end
      end
      properties
    rescue StandardError => e
      Rails.logger.error(e.backtrace)
      raise
    end

    def self.properties_handler(data, properties)
      properties && properties['layers'] && properties['layers'].keys&.each do |key|
        layer = properties['layers'][key]
        properties = proc_molecule(layer, key, data, properties)
        properties = proc_table(layer, key, data, properties)
        # properties = proc_sample(layer, key, data, properties)
      end
      properties
    rescue StandardError => e
      Rails.logger.error(e.backtrace)
      raise
    end

    def self.create_segment_klass(sk_obj, segment_klass, element_klass, current_user_id)
      return if segment_klass.present? || element_klass.nil? || sk_obj.nil?

      segment_klass = Labimotion::SegmentKlass.create!(sk_obj.slice(
          'label',
          'desc',
          'properties_template',
          'is_active',
          'place',
          'properties_release',
          'uuid',
          'identifier',
          'sync_time'
        ).merge(
          element_klass: element_klass,
          created_by: current_user_id,
          released_at: DateTime.now
        )
      )

      segment_klass
    end
  end
end
