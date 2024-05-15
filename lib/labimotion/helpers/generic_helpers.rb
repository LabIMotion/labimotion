# frozen_string_literal: true
require 'grape'
require 'labimotion/conf'
require 'labimotion/utils/utils'
# Helper for associated sample
module Labimotion
  ## Generic Helpers
  module GenericHelpers
    extend Grape::API::Helpers

    def authenticate_admin!(type)
      error!('401 Unauthorized', 401) unless current_user.generic_admin[type]
    end

    def fetch_klass(name, id)
      klz = "Labimotion::#{name}".constantize.find_by(id: id)
      error!("#{name.gsub(/(Klass)/, '')} is invalid. Please re-select.", 500) if klz.nil?
      klz
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      raise e
    end

    def deactivate_klass(params)
      klz = fetch_klass(params[:klass], params[:id])
      klz&.update!(is_active: params[:is_active])
      generate_klass_file unless klz.class.name != 'Labimotion::ElementKlass'
      klz
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      raise e
    end

    def delete_klass(params)
      authenticate_admin!(params[:klass].gsub(/(Klass)/, 's').downcase)
      klz = fetch_klass(params[:klass], params[:id])
      klz&.destroy!
      generate_klass_file unless klz.class.name != 'Labimotion::ElementKlass'
      status 201
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      raise e
    end

    def update_template(params, current_user)
      klz = fetch_klass(params[:klass], params[:id])
      uuid = SecureRandom.uuid
      properties = params[:properties_template]
      properties['uuid'] = uuid
      klz.version = Labimotion::Utils.next_version(params[:release], klz.version)
      properties['version'] = klz.version
      properties['pkg'] = Labimotion::Utils.pkg(params['pkg'] || (klz.properties_template && klz.properties_template['pkg']))
      properties['klass'] = klz.class.name.split('::').last
      properties['identifier'] = klz.identifier
      properties.delete('eln') if properties['eln'].present?
      klz.updated_by = current_user.id
      klz.properties_template = properties
      klz.save!
      klz.reload
      klz.create_klasses_revision(current_user) if params[:release] != 'draft'
      klz
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      raise e
    end

    def delete_klass_revision(params)
      revision = "Labimotion::#{params[:klass]}esRevision".constantize.find(params[:id])
      klass = "Labimotion::#{params[:klass]}".constantize.find_by(id: params[:klass_id]) unless revision.nil?
      error!('Revision is invalid.', 404) if revision.nil?
      error!('Can not delete the active revision.', 405) if revision.uuid == klass.uuid
      revision&.destroy!
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      raise e
    end

    def delete_revision(params)
      revision = "Labimotion::#{params[:klass]}sRevision".constantize.find(params[:id])
      element = "Labimotion::#{params[:klass]}".constantize.find_by(id: params[:element_id]) unless revision.nil?
      error!('Revision is invalid.', 404) if revision.nil?
      error!('Can not delete the active revision.', 405) if revision.uuid == element.uuid
      revision&.destroy!
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      raise e
    end

    def list_klass_revisions(params)
      klass = "Labimotion::#{params[:klass]}".constantize.find_by(id: params[:id])
      list = klass.send("#{params[:klass].underscore}es_revisions") unless klass.nil?
      list&.order(released_at: :desc)&.limit(10)
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      raise e
    end


    ###############
    def generate_klass_file
      klass_names_file = Labimotion::KLASSES_JSON # Rails.root.join('app/packs/klasses.json')
      klasses = Labimotion::ElementKlass.where(is_active: true)&.pluck(:name) || []
      File.write(klass_names_file, klasses)
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      raise e
    end

    def fetch_properties_uploads(properties)
      uploads = []
      properties[Labimotion::Prop::LAYERS].keys.each do |key|
        layer = properties[Labimotion::Prop::LAYERS][key]
        field_uploads = layer[Labimotion::Prop::FIELDS].select { |ss| ss['type'] == Labimotion::FieldType::UPLOAD }
        field_uploads.each do |field|
          ((field['value'] && field['value']['files']) || []).each do |file|
            uploads.push({ layer: key, field: field['field'], uid: file['uid'], filename: file['filename'] })
          end
        end
      end
      uploads
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      raise e
    end

    def update_properties_upload(element, properties, att, pa)
      return if pa.nil?

      idx = properties[Labimotion::Prop::LAYERS][pa[:layer]][Labimotion::Prop::FIELDS].index { |fl| fl['field'] == pa[:field] }
      fidx = properties[Labimotion::Prop::LAYERS][pa[:layer]][Labimotion::Prop::FIELDS][idx]['value']['files'].index { |fi| fi['uid'] == pa[:uid] }
      properties[Labimotion::Prop::LAYERS][pa[:layer]][Labimotion::Prop::FIELDS][idx]['value']['files'][fidx]['aid'] = att.id
      properties[Labimotion::Prop::LAYERS][pa[:layer]][Labimotion::Prop::FIELDS][idx]['value']['files'][fidx]['uid'] = att.identifier
      element.update_columns(properties: properties)
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      raise e
    end

    def create_uploads(type, id, files, param_info, user_id)
      return if files.nil? || param_info.nil? || files.empty? || param_info.empty?

      attach_ary = []
      map_info = JSON.parse(param_info)
      map_info&.keys&.each do |key|
        next if map_info[key]['files'].empty?

        if type == Labimotion::Prop::SEGMENT
          element = Labimotion::Segment.find_by(element_id: id, segment_klass_id: key)
        elsif type == Labimotion::Prop::ELEMENT
          element = Labimotion::Element.find_by(id: id)
        end
        next if element.nil?

        uploads = fetch_properties_uploads(element.properties)

        map_info[key]['files'].each do |fobj|
          file = (files || []).select { |ff| ff['filename'] == fobj['uid'] }&.first
          pa = uploads.select { |ss| ss[:uid] == file[:filename] }&.first || nil
          next unless (tempfile = file[:tempfile])

          a = Attachment.new(
            bucket: file[:container_id],
            filename: fobj['filename'],
            con_state: Labimotion::ConState::NONE,
            file_path: file[:tempfile],
            created_by: user_id,
            created_for: user_id,
            content_type: file[:type],
            attachable_type: map_info[key]['type'],
            attachable_id: element.id,
          )
          begin
            a.save!

            update_properties_upload(element, element.properties, a, pa)
            attach_ary.push(a.id)
          ensure
            tempfile.close
            tempfile.unlink
          end
        end
        element.send("#{type.downcase}s_revisions")&.last&.destroy!
        element.save!
      end
      attach_ary
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      error!('Error while uploading files.', 500)
      raise e
    end

    def create_attachments(files, del_files, type, id, identifier, user_id)
      attach_ary = []
      (files || []).each_with_index do |file, index|
        next unless (tempfile = file[:tempfile])

        att = Attachment.new(
          bucket: file[:container_id],
          filename: file[:filename],
          con_state: Labimotion::ConState::NONE,
          file_path: file[:tempfile],
          created_by: user_id,
          created_for: user_id,
          identifier: identifier[index],
          content_type: file[:type],
          attachable_type: type,
          attachable_id: id,
        )
        begin
          att.save!
          attach_ary.push(att.id)
        ensure
          tempfile.close
          tempfile.unlink
        end
      end
      unless (del_files || []).empty?
        Attachment.where('id IN (?) AND attachable_type = (?)', del_files.map!(&:to_i), type).update_all(attachable_id: nil)
      end
      attach_ary
    rescue StandardError => e
      Labimotion.log_exception(e)
      raise e
    end

    def fetch_repo_generic_template(klass, identifier)
      Chemotion::Generic::Fetch::Template.exec(API::TARGET, klass, identifier)
    end

    def fetch_repo_generic_template_list(name = false)
      Chemotion::Generic::Fetch::Template.list(API::TARGET, name)
    end

    def fetch_repo(name, current_user)
      # current_klasses = "Labimotion::#{name}".constantize.where.not(identifier: nil)&.pluck(:identifier) || []
      response = Labimotion::TemplateHub.list(name)
      # if response && response['list'].present? && response['list'].length.positive?
        # filter_list = response['list']&.reject do |ds|
        #   current_klasses.include?(ds['identifier'])
        # end || []
      # end
      # filter_list || []
      (response && response['list']) || []
    rescue StandardError => e
      Labimotion.log_exception(e, current_user)
      { error: 'Cannot connect to Chemotion Repository' }
    end
  end
end
