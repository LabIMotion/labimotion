# frozen_string_literal: true

require 'labimotion/version'
require 'labimotion/utils/utils'

module Labimotion
  ## NmrMapper
  class NmrMapper
    def self.process_ds(id, current_user = {})
      att = Attachment.find_by(id: id, con_state: Labimotion::ConState::NMR)
      return if att.nil?

      result = is_brucker_binary(id)
      if result[:is_bagit] == true
        att.update_column(:con_state, Labimotion::ConState::CONVERTED)
        Labimotion::Converter.metadata(id)
        Labimotion::ConState::COMPLETED
      elsif result[:metadata] == nil
        Labimotion::ConState::NONE
      else
        ds = Container.find_by(id: att.attachable_id)
        return if ds.nil? || ds.parent&.container_type != 'analysis'

        data = process(att, id, result[:metadata])
        generate_ds(id, att.attachable_id, data, current_user)
        Labimotion::ConState::COMPLETED
      end
    end

    def self.is_brucker_binary(id)
      att = Attachment.find_by(id: id, con_state: Labimotion::ConState::NMR)
      return if att.nil?

      if att&.attachment_attacher&.file&.url
        Zip::File.open(att.attachment_attacher.file.url) do |zip_file|
          zip_file.each do |entry|
            if entry.name.include?('/pdata/') && entry.name.include?('parm.txt')
              metadata = entry.get_input_stream.read.force_encoding('UTF-8')
              return { is_bagit: false, metadata: metadata }
            elsif entry.name.include?('metadata/') && entry.name.include?('converter.json')
              return { is_bagit: true, metadata: nil }
            end
          end
        end
      end
      { is_bagit: false, metadata: nil }
    end

    def self.process(att, id, content)
      return if att.nil? || content.nil?

      lines = content.split("\n").reject(&:empty?)
      metadata = {}
      lines.map do |ln|
        arr = ln.split(/\s+/)
        metadata[arr[0]] = arr[1..-1].join(' ') if arr.length > 1
      end
      ols = 'CHMO:0000593' if metadata['NUC1'] == '1H'
      ols = 'CHMO:0000595' if metadata['NUC1'] == '13C'

      { content: { metadata: metadata, ols: ols } }
      # if content.present? && att.present?
      #   Labimotion::NmrMapper.ts('write', att.attachable_id,
      #                         content: { metadata: metadata, ols: ols })
      # end
    end

    def self.fetch_content(id)
      atts = Attachment.where(attachable_id: id)
      return if atts.nil?

      atts.each do |att|
        content = Labimotion::NmrMapper.ts('read', att.id)
        return content if content.present?
      end
    end


    def self.generate_ds(id, cid, data, current_user = {})
      return if data.nil? || cid.nil?

      obj = Labimotion::NmrMapper.build_ds(cid, data[:content])
      return if obj.nil? || obj[:ols].nil?

      Labimotion::NmrMapper.update_ds_1h(cid, obj, current_user) if obj[:ols] == 'CHMO:0000593'
      Labimotion::NmrMapper.update_ds_1h(cid, obj, current_user) if obj[:ols] == 'CHMO:0000595'
    end

    def self.update_ds_13c(id, obj)
      # dataset = obj[:dataset]
      # metadata = obj[:metadata]
      # new_prop = dataset.properties

      # dataset.properties = new_prop
      # dataset.save!
    end

    def self.set_data(prop, field, idx, layer_name, field_name, value)
      return if field['field'] != field_name || value&.empty?

      field['value'] = value
      prop[Labimotion::Prop::LAYERS][layer_name][Labimotion::Prop::FIELDS][idx] = field
      prop
    end

    def self.update_ds_1h(id, obj, current_user)
      dataset = obj[:dataset]
      metadata = obj[:metadata]
      new_prop = dataset.properties
      new_prop.dig(Labimotion::Prop::LAYERS, 'general', Labimotion::Prop::FIELDS)&.each_with_index do |fi, idx|
        #  new_prop = set_data(new_prop, fi, idx, 'general', 'title', metadata['NAME'])
        if fi['field'] == 'title' && metadata['NAME'].present?
          ## fi['label'] = fi['label']
          fi['value'] = metadata['NAME']
          fi['device'] = metadata['NAME']
          fi['dkey'] = 'NAME'
          new_prop[Labimotion::Prop::LAYERS]['general'][Labimotion::Prop::FIELDS][idx] = fi
        end

        if fi['field'] == 'date' && metadata['Date_'].present?
          ## fi['label'] = fi['label']
          fi['value'] = metadata['Date_']
          fi['device'] = metadata['Date_']
          fi['dkey'] = 'Date_'
          new_prop[Labimotion::Prop::LAYERS]['general'][Labimotion::Prop::FIELDS][idx] = fi
        end

        if fi['field'] == 'time' && metadata['Time'].present?
          ## fi['label'] = fi['label']
          fi['value'] = metadata['Time']
          fi['device'] = metadata['Time']
          fi['dkey'] = 'Time'
          new_prop[Labimotion::Prop::LAYERS]['general'][Labimotion::Prop::FIELDS][idx] = fi
        end

        if fi['field'] == 'creator' && current_user.present?
          ## fi['label'] = fi['label']
          fi['value'] = current_user.name
          new_prop[Labimotion::Prop::LAYERS]['general'][Labimotion::Prop::FIELDS][idx] = fi
        end
      end
      element = Container.find(id)&.root_element
      element.present? && element&.class&.name == 'Sample' && new_prop.dig(Labimotion::Prop::LAYERS, 'sample_details',
                                                                          Labimotion::Prop::FIELDS)&.each_with_index do |fi, idx|
        if fi['field'] == 'label'
          fi['value'] = element.short_label
          new_prop[Labimotion::Prop::LAYERS]['sample_details'][Labimotion::Prop::FIELDS][idx] = fi
        end
        if fi['field'] == 'id'
          fi['value'] = element.id
          new_prop[Labimotion::Prop::LAYERS]['sample_details'][Labimotion::Prop::FIELDS][idx] = fi
        end
      end

      new_prop.dig(Labimotion::Prop::LAYERS, 'instrument', Labimotion::Prop::FIELDS)&.each_with_index do |fi, idx|
        if fi['field'] == 'instrument' && metadata['INSTRUM'].present?
          ## fi['label'] = fi['label']
          fi['value'] = metadata['INSTRUM']
          fi['device'] = metadata['INSTRUM']
          fi['dkey'] = 'INSTRUM'
          new_prop[Labimotion::Prop::LAYERS]['instrument'][Labimotion::Prop::FIELDS][idx] = fi
        end
      end

      new_prop.dig(Labimotion::Prop::LAYERS, 'equipment', Labimotion::Prop::FIELDS)&.each_with_index do |fi, idx|
        if fi['field'] == 'probehead' && metadata['PROBHD'].present?
          ## fi['label'] = fi['label']
          fi['value'] = metadata['PROBHD']
          fi['device'] = metadata['PROBHD']
          fi['dkey'] = 'PROBHD'
          new_prop[Labimotion::Prop::LAYERS]['equipment'][Labimotion::Prop::FIELDS][idx] = fi
        end
      end

      new_prop.dig(Labimotion::Prop::LAYERS, 'sample_preparation', Labimotion::Prop::FIELDS)&.each_with_index do |fi, idx|
        if fi['field'] == 'solvent' && metadata['SOLVENT'].present?
          ## fi['label'] = fi['label']
          fi['value'] = metadata['SOLVENT']
          fi['device'] = metadata['SOLVENT']
          fi['dkey'] = 'SOLVENT'
          fi['value'] = 'chloroform-D1 (CDCl3)' if metadata['SOLVENT'] == 'CDCl3'
          new_prop[Labimotion::Prop::LAYERS]['sample_preparation'][Labimotion::Prop::FIELDS][idx] = fi
        end
      end

      new_prop.dig(Labimotion::Prop::LAYERS, 'set', Labimotion::Prop::FIELDS)&.each_with_index do |fi, idx|
        if fi['field'] == 'temperature' && metadata['TE'].present?
          ## fi['label'] = fi['label']
          fi['value'] = metadata['TE'].split(/\s+/).first
          fi['device'] = metadata['TE']
          fi['dkey'] = 'TE'
          fi['value_system'] = metadata['TE'].split(/\s+/).last
          new_prop[Labimotion::Prop::LAYERS]['set'][Labimotion::Prop::FIELDS][idx] = fi
        end
        if fi['field'] == 'ns' && metadata['NS'].present?
          ## fi['label'] = fi['label']
          fi['value'] = metadata['NS']
          fi['device'] = metadata['NS']
          fi['dkey'] = 'NS'
          new_prop[Labimotion::Prop::LAYERS]['set'][Labimotion::Prop::FIELDS][idx] = fi
        end
        if fi['field'] == 'PULPROG' && metadata['PULPROG'].present?
          ## fi['label'] = fi['label']
          fi['value'] = metadata['PULPROG']
          fi['device'] = metadata['PULPROG']
          fi['dkey'] = 'PULPROG'
          new_prop[Labimotion::Prop::LAYERS]['set'][Labimotion::Prop::FIELDS][idx] = fi
        end
        if fi['field'] == 'td' && metadata['TD'].present?
          ## fi['label'] = fi['label']
          fi['value'] = metadata['TD']
          fi['device'] = metadata['TD']
          fi['dkey'] = 'TD'
          new_prop[Labimotion::Prop::LAYERS]['set'][Labimotion::Prop::FIELDS][idx] = fi
        end
        if fi['field'] == 'done' && metadata['D1'].present?
          ## fi['label'] = fi['label']
          fi['value'] = metadata['D1']
          fi['device'] = metadata['D1']
          fi['dkey'] = 'D1'
          new_prop[Labimotion::Prop::LAYERS]['set'][Labimotion::Prop::FIELDS][idx] = fi
        end
        if fi['field'] == 'sf' && metadata['SF'].present?
          ## fi['label'] = fi['label']
          fi['value'] = metadata['SF']
          fi['device'] = metadata['SF']
          fi['dkey'] = 'SF'
          new_prop[Labimotion::Prop::LAYERS]['set'][Labimotion::Prop::FIELDS][idx] = fi
        end
        if fi['field'] == 'sfoone' && metadata['SFO1'].present?
          ## fi['label'] = fi['label']
          fi['value'] = metadata['SFO1']
          fi['device'] = metadata['SFO1']
          fi['dkey'] = 'SFO1'
          new_prop[Labimotion::Prop::LAYERS]['set'][Labimotion::Prop::FIELDS][idx] = fi
        end
        if fi['field'] == 'sfotwo' && metadata['SFO2'].present?
          ## fi['label'] = fi['label']
          fi['value'] = metadata['SFO2']
          fi['device'] = metadata['SFO2']
          fi['dkey'] = 'SFO2'
          new_prop[Labimotion::Prop::LAYERS]['set'][Labimotion::Prop::FIELDS][idx] = fi
        end
        if fi['field'] == 'nucone' && metadata['NUC1'].present?
          ## fi['label'] = fi['label']
          fi['value'] = metadata['NUC1']
          fi['device'] = metadata['NUC1']
          fi['dkey'] = 'NUC1'
          new_prop[Labimotion::Prop::LAYERS]['set'][Labimotion::Prop::FIELDS][idx] = fi
        end
        if fi['field'] == 'nuctwo' && metadata['NUC2'].present?
          ## fi['label'] = fi['label']
          fi['value'] = metadata['NUC2']
          fi['device'] = metadata['NUC2']
          fi['dkey'] = 'NUC2'
          new_prop[Labimotion::Prop::LAYERS]['set'][Labimotion::Prop::FIELDS][idx] = fi
        end
      end
      dataset.properties = new_prop
      dataset.save!
    end

    def self.ts(method, identifier, params = nil)
      Rails.cache.send(method, "#{Labimotion::NmrMapper.new.class.name}#{identifier}", params)
    end

    def self.clean(id)
      Labimotion::NmrMapper.ts('delete', id)
    end

    def self.build_ds(id, content)
      ds = Container.find_by(id: id)
      return if ds.nil? || content.nil?

      ols = content[:ols]
      metadata = content[:metadata]

      return if ols.nil? || metadata.nil?

      klass = Labimotion::DatasetKlass.find_by(ols_term_id: ols)
      return if klass.nil?

      uuid = SecureRandom.uuid
      props = klass.properties_release
      props['uuid'] = uuid
      props['pkg'] = Labimotion::Utils.pkg(props['pkg'])
      props['klass'] = 'Dataset'
      dataset = Labimotion::Dataset.create!(
        uuid: uuid,
        dataset_klass_id: klass.id,
        element_type: 'Container',
        element_id: ds.id,
        properties: props,
        properties_release: klass.properties_release,
        klass_uuid: klass.uuid,
      )
      { dataset: dataset, metadata: metadata, ols: ols }
    end
  end
end
