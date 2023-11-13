# frozen_string_literal: true

module Labimotion
  class SampleAssociation
    def self.build_sample(sid, cols, current_user, cr_opt)
      parent_sample = Sample.find(sid)
      case cr_opt
      when 0
        subsample = parent_sample
        collections = Collection.where(id: cols).where.not(id: subsample.collections.pluck(:id))
        subsample.collections << collections unless collections.empty?
      when 1
        subsample = parent_sample.create_subsample(current_user, cols, true)
      when 2
        subsample = parent_sample.dup
        subsample.parent = nil
        collections = (Collection.where(id: cols) | Collection.where(user_id: current_user.id, label: 'All', is_locked: true))
        subsample.collections << collections
        subsample.container = Container.create_root_container
      else
        return nil
      end

      return nil if subsample.nil?

      subsample.save!
      subsample.reload
      subsample
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      nil
    end

    def self.build_table_sample(field_tables, current_user, element = nil)
      sds = []
      field_tables.each do |field|
        next unless field['sub_values'].present? && field['sub_fields'].present?

        field_table_samples = field['sub_fields'].select { |ss| ss['type'] == 'drag_sample' }
        next unless field_table_samples.present?

        col_ids = field_table_samples.map { |x| x.values[0] }
        col_ids.each do |col_id|
          field['sub_values'].each do |sub_value|
            next unless sub_value[col_id].present? && sub_value[col_id]['value'].present? && sub_value[col_id]['value']['el_id'].present?

            svalue = sub_value[col_id]['value']
            sid = svalue['el_id']
            next unless sid.present?

            sds << sid unless svalue['is_new']
            next unless svalue['is_new']

            cr_opt = svalue['cr_opt']
            next if element.nil?

            subsample = Labimotion::SampleAssociation.build_sample(sid, element.collections, current_user, cr_opt) unless sid.nil? || cr_opt.nil?
            next if subsample.nil?

            sds << subsample.id
            sub_value[col_id]['value']['el_id'] = subsample.id
            sub_value[col_id]['value']['is_new'] = false
            Labimotion::ElementsSample.find_or_create_by(element_id: element.id, sample_id: subsample.id)
          end
        end
      end
      sds
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      []
    end

    def self.update_sample_association(properties, current_user, element = nil)
      sds = []
      els = []
      properties['layers'].keys.each do |key|
        layer = properties['layers'][key]
        field_samples = layer['fields'].select { |ss| ss['type'] == 'drag_sample' }
        field_samples.each do |field|
          idx = properties['layers'][key]['fields'].index(field)
          sid = field.dig('value', 'el_id')
          next if sid.blank?

          sds << sid unless properties.dig('layers', key, 'fields', idx, 'value', 'is_new') == true
          next unless properties.dig('layers', key, 'fields', idx, 'value', 'is_new') == true

          cr_opt = field.dig('value', 'cr_opt')
          subsample = Labimotion::SampleAssociation.build_sample(sid, element&.collections, current_user, cr_opt) unless sid.nil? || cr_opt.nil?
          next if subsample.nil?

          sds << subsample.id
          properties['layers'][key]['fields'][idx]['value']['el_id'] = subsample.id
          properties['layers'][key]['fields'][idx]['value']['el_label'] = subsample.short_label
          properties['layers'][key]['fields'][idx]['value']['el_tip'] = subsample.short_label
          properties['layers'][key]['fields'][idx]['value']['is_new'] = false
          Labimotion::ElementsSample.find_or_create_by(element_id: element.id, sample_id: subsample.id) if element.present?
        end
        field_tables = properties['layers'][key]['fields'].select { |ss| ss['type'] == 'table' }
        sds << Labimotion::SampleAssociation.build_table_sample(field_tables, current_user, element) if element.present?
        field_elements = layer['fields'].select { |ss| ss['type'] == 'drag_element' }
        field_elements.each do |field|
          idx = properties['layers'][key]['fields'].index(field)
          sid = field.dig('value', 'el_id')
          next if element.nil? || sid.blank? || sid == element.id

          el = Labimotion::Element.find_by(id: sid)
          next if el.nil?

          Labimotion::ElementsElement.find_or_create_by(parent_id: element.id, element_id: el.id)
          els << el.id
        end

      end
      if element.present?
        es_list = Labimotion::ElementsSample.where(element_id: element.id).where.not(sample_id: sds)
        ee_list = Labimotion::ElementsElement.where(parent_id: element.id).where.not(element_id: els&.flatten)
        es_list.destroy_all if es_list.present?
        ee_list.destroy_all if ee_list.present?
      end
      properties
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
    end
  end
end
