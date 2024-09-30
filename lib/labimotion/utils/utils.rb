# frozen_string_literal: true

require 'labimotion/version'
module Labimotion
  ## Generic Utils
  class Utils
    def self.klass_by_collection(name)
      names = name.split('::')
      if names.size == 1
        name[11..]
      else
        "#{names[0]}::#{names.last[11..]}"
      end
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      name
    end

    def self.elname_by_collection(name)
      names = name.split('::')
      if names.size == 1
        name[11..].underscore
      else
        names.last[11..].underscore
      end
    rescue StandardError => e
      Labimotion.log_exception(e)
      name.constantize
    end

    def self.col_by_element(name)
      names = name.split('::')
      if names.size == 1
        "collections_#{name.underscore.pluralize}"
      else
        "collections_#{names.last.underscore.pluralize}"
      end
    rescue StandardError => e
      Labimotion.log_exception(e)
      name..underscore.pluralize
    end

    def self.element_name(name)
      names = name.split('::')
      if names.size == 1
        name
      else
        names.last
      end
    rescue StandardError => e
      Labimotion.log_exception(e)
      name
    end

    def self.element_name_dc(name)
      Labimotion::Utils.element_name(name)&.downcase
    end

    def self.next_version(release, current_version)
      case release
      when 'draft'
        current_version
      when 'major'
        if current_version.nil? || current_version.split('.').length < 2
          '1.0'
        else
          "#{current_version&.split('.').first.to_i + 1}.0"
        end
      when 'minor'
        if current_version.nil? || current_version&.split('.').length < 2
          '0.1'
        else
          "#{current_version&.split('.').first.to_i.to_s}.#{current_version&.split('.').last.to_i + 1}"
        end
      else
        current_version
      end
    rescue StandardError => e
      Labimotion.log_exception(e)
      current_version
    end

    def self.find_field(properties, field_path, separator = '.')
      return if properties.nil? || field_path.nil?

      layer_name, field_name = field_path.split(separator)
      fields = properties.dig(Labimotion::Prop::LAYERS, layer_name, Labimotion::Prop::FIELDS)
      return unless fields

      fields.find { |f| f['field'] == field_name }
    end

    def self.find_options_val(field, properties)
      return if field.nil? || properties.nil? || field['option_layers'].nil? || field['value'].nil?

      option_layers = properties.dig(Labimotion::Prop::SEL_OPTIONS, field['option_layers'])
      options = option_layers && option_layers['options']
      return if options.nil?

      sel_option = options.find { |o| o['key'] == field['value'] }
      sel_option && sel_option['label']
    end

    def self.pkg(pkg)
      pkg = {} if pkg.nil?
      pkg['eln'] = Chemotion::Application.config.version
      pkg['labimotion'] = Labimotion::VERSION
      pkg
    end
  end
end
