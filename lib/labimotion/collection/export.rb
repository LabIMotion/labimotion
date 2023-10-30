# frozen_string_literal: true

module Labimotion
  ## Export
  class Export

    def self.fetch_element_klasses(&fetch_many)
      klasses = Labimotion::ElementKlass.where(is_active: true)
      fetch_many.call(klasses, {'created_by' => 'User'})
    end

    def self.fetch_segment_klasses(&fetch_many)
      klasses = Labimotion::SegmentKlass.where(is_active: true)
      fetch_many.call(klasses, {
        'element_klass_id' => 'Labimotion::ElementKlass',
        'created_by' => 'User'
        })
    end

    def self.fetch_dataset_klasses(&fetch_many)
      klasses = Labimotion::DatasetKlass.where(is_active: true)
      fetch_many.call(klasses, {'created_by' => 'User'})
    end

    def self.fetch_elements(collection, segments, attachments, fetch_many, fetch_one, fetch_containers)
      # fetch_many.call(collection.elements, {
      #   'element_klass_id' => 'Labimotion::ElementKlass',
      #   'created_by' => 'User',
      # })
      # fetch_many.call(collection.collections_elements, {
      #         'collection_id' => 'Collection',
      #         'element_id' => 'Labimotion::Element',
      # })
      collection.elements.each do |element|
        element, attachments = Labimotion::Export.fetch_properties(data, element, attachments, &fetch_one)
        fetch_one.call(element, {
          'element_klass_id' => 'Labimotion::ElementKlass',
          'created_by' => 'User',
        })
        fetch_containers.call(element)
        segment, @attachments = Labimotion::Export.fetch_segments(element, attachments, &fetch_one)
        segments += segment if segment.present?
      end

      [segments, attachments]

    end

    def self.fetch_segments(element, attachments, &fetch_one)
      element_type = element.class.name
      segments = Labimotion::Segment.where("element_id = ? AND element_type = ?", element.id, element_type)
      segments.each do |segment|
        # segment = fetch_properties(segment)
        segment, attachments = Labimotion::Export.fetch_properties(segment, attachments, &fetch_one)
        # fetch_one.call(segment.segment_klass.element_klass)
        # fetch_one.call(segment.segment_klass, {
        #   'element_klass_id' => 'Labimotion::ElementKlass'
        # })
        fetch_one.call(segment, {
          'element_id' => segment.element_type,
          'segment_klass_id' => 'Labimotion::SegmentKlass',
          'created_by' => 'User'
        })
      end
      [segments, attachments]
    end

    def self.fetch_datasets(dataset, &fetch_one)
      return if dataset.nil?

      fetch_one.call(dataset, {
        'element_id' => 'Container',
      })
      fetch_one.call(dataset, {
        'element_id' => dataset.element_type,
        'dataset_klass_id' => 'Labimotion::DatasetKlass',
      })
      [dataset]
    end


    def self.fetch_properties(instance, attachments, &fetch_one)
      properties = instance.properties
      properties['layers'].keys.each do |key|
        layer = properties['layers'][key]

        # field_samples = layer['fields'].select { |ss| ss['type'] == 'drag_sample' }  -- TODO for elements
        # field_elements = layer['fields'].select { |ss| ss['type'] == 'drag_element' }  -- TODO for elements

        field_molecules = layer['fields'].select { |ss| ss['type'] == 'drag_molecule' }
        field_molecules.each do |field|
          idx = properties['layers'][key]['fields'].index(field)
          id = field["value"] && field["value"]["el_id"] unless idx.nil?
          mol = Molecule.find(id) unless id.nil?
          properties['layers'][key]['fields'][idx]['value']['el_id'] = fetch_one.call(mol) unless mol.nil?
        end

        field_samples = layer['fields'].select { |ss| ss['type'] == 'drag_sample' }
        field_samples.each do |field|
          # idx = properties['layers'][key]['fields'].index(field)
          # id = field["value"] && field["value"]["el_id"] unless idx.nil?
          # ss = Sample.find(id) unless id.nil?
          # properties['layers'][key]['fields'][idx]['value']['el_id'] = fetch_one.call(ss) unless ss.nil?
        end

        field_uploads = layer['fields'].select { |ss| ss['type'] == 'upload' }
        field_uploads.each do |upload|
          idx = properties['layers'][key]['fields'].index(upload)
          files = upload["value"] && upload["value"]["files"]
          files&.each_with_index do |fi, fdx|
            att = Attachment.find(fi['aid'])
            attachments += [att]
            properties['layers'][key]['fields'][idx]['value']['files'][fdx]['aid'] = fetch_one.call(att, {'attachable_id' => 'Labimotion::Segment'}) unless att.nil?
          end
        end

        field_tables = properties['layers'][key]['fields'].select { |ss| ss['type'] == 'table' }
        field_tables&.each do |field|
          next unless field['sub_values'].present? && field['sub_fields'].present?
          # field_table_samples = field['sub_fields'].select { |ss| ss['type'] == 'drag_sample' }  -- not available yet
          # field_table_uploads = field['sub_fields'].select { |ss| ss['type'] == 'upload' }       -- not available yet
          field_table_molecules = field['sub_fields'].select { |ss| ss['type'] == 'drag_molecule' }
          if field_table_molecules.present?
            col_ids = field_table_molecules.map { |x| x.values[0] }
            col_ids.each do |col_id|
              field['sub_values'].each do |sub_value|
                next unless sub_value[col_id].present? && sub_value[col_id]['value'].present? && sub_value[col_id]['value']['el_id'].present?

                svalue = sub_value[col_id]['value']
                next unless svalue['el_id'].present? && svalue['el_inchikey'].present?

                tmol = Molecule.find_by(id: svalue['el_id'])
                sub_value[col_id]['value']['el_id'] = fetch_one.call(tmol) unless tmol.nil?
              end
            end
          end
        end
      end
      instance.properties = properties
      [instance, attachments]
    end
  end
end
