# frozen_string_literal: true

require 'cgi'
require 'labimotion/conf'
require 'labimotion/libs/export_element'

module Labimotion
  # Generic Element API
  class GenericElementAPI < Grape::API
    include Grape::Kaminari
    helpers ContainerHelpers
    helpers ParamsHelpers
    helpers CollectionHelpers
    helpers UserLabelHelpers
    helpers Labimotion::SampleAssociationHelpers
    helpers Labimotion::VocabularyHelpers
    helpers Labimotion::GenericHelpers
    helpers Labimotion::ElementHelpers
    helpers Labimotion::ParamHelpers

    resource :generic_elements do
      # might be removed because the file is moved to public folder
      namespace :current do
        desc 'Return serialized elements of current user'
        get do
          klasses_json_path = Labimotion::KLASSES_JSON # Rails.root.join('app/packs/klasses.json')
          klasses = JSON.parse(File.read(klasses_json_path))
          { klasses: klasses }
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          { klasses: [] }
        end
      end

      namespace :klass do
        desc 'get klass info'
        params do
          requires :name, type: String, desc: 'element klass name'
        end
        get do
          ek = Labimotion::ElementKlass.find_by(name: params[:name])
          present ek, with: Labimotion::ElementKlassEntity, root: 'klass'
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          { klass: [] }
        end
      end

      namespace :klasses do
        desc 'get klasses'
        params do
          optional :generic_only, type: Boolean, desc: 'list generic element only'
        end
        get do
          list = klass_list(params[:generic_only])
          present list, with: Labimotion::ElementKlassEntity, root: 'klass'
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          { klass: [] }
        end
      end

      namespace :search_by_like do
        desc 'Search elements by name (case-insensitive like search)'
        params do
          requires :name, type: String, desc: 'Search query for element name'
          requires :short_label, type: String, desc: 'Search query for element short label'
          requires :klass_id, type: Integer, desc: 'Filter by element klass id'
          optional :limit, type: Integer, desc: 'Maximum number of results', default: 20
        end
        get do
          scope = Labimotion::Element.fetch_for_user(
            current_user.id,
            name: params[:name],
            short_label: params[:short_label],
            klass_id: params[:klass_id],
            limit: params[:limit]
          )

          results = scope.map do |element|
            Labimotion::ElementLookupEntity.represent(element)
          end

          { elements: results, total_count: results.count }
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          { elements: [], total_count: 0, error: e.message }
        end
      end

      namespace :search_basic_by_like do
        desc 'Search basic elements by name and short label (case-insensitive like search)'
        params do
          requires :klass_name, type: String, desc: 'Class name (device_description or wellplate or ...etc.)', default: 'device_description'
          requires :name, type: String, desc: 'Search query for basic element name'
          requires :short_label, type: String, desc: 'Search query for basic element short label'
          optional :limit, type: Integer, desc: 'Maximum number of results', default: 20
        end
        get do
          # Convert snake_case to PascalCase (e.g. device_description -> DeviceDescription)
          klass_name = params[:klass_name].camelize
          klass = "Labimotion::#{klass_name}".constantize

          scope = klass.fetch_for_user(
            current_user.id,
            name: params[:name],
            short_label: params[:short_label],
            limit: params[:limit]
          )

          results = scope.map do |record|
            Labimotion::ElementLookupEntity.represent(record)
          end

          { elements: results, total_count: results.count }
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          { elements: [], total_count: 0, error: e.message }
        end
      end

      namespace :export do
        desc 'export element'
        params do
          requires :id, type: Integer, desc: 'element id'
          requires :klass, type: String, desc: 'Klass', values: %w[Element Segment Dataset]
          optional :export_format, type: String, desc: 'export format'
        end
        get do
          case params[:klass]
          when 'Element'
            element = Labimotion::Element.find(params[:id])
          when 'Segment'
            element = Labimotion::Segment.find(params[:id])
          when 'Dataset'
            element = Labimotion::Dataset.find(params[:id])
          end
          export = Labimotion::ExportElement.new current_user, element, params[:export_format]
          env['api.format'] = :binary
          content_type 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
          el_filename = export.res_name
          filename = CGI.escape(el_filename)
          # header['Content-Disposition'] = "attachment; filename=abc.docx"
          header('Content-Disposition', "attachment; filename=\"#{filename}\"")

          export.to_docx
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          { klass: [] }
        end
      end

      namespace :create_element_klass do
        desc 'create Generic Element Klass'
        params do
          use :create_element_klass_params
        end
        post do
          authenticate_admin!('elements')
          create_element_klass(current_user, params)
          status 201
        rescue ActiveRecord::RecordInvalid => e
          { error: e.message }
        end
      end

      namespace :update_element_klass do
        desc 'update Generic Element Klass'
        params do
          use :update_element_klass_params
        end
        post do
          authenticate_admin!('elements')
          update_element_klass(current_user, params)
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          raise e
        end
      end

      namespace :klass_revisions do
        desc 'list Generic Element Revisions'
        params do
          requires :id, type: Integer, desc: 'Generic Element Klass Id'
          requires :klass, type: String, desc: 'Klass', values: %w[ElementKlass SegmentKlass DatasetKlass]
        end
        get do
          list = list_klass_revisions(params)
          present list, with: Labimotion::KlassRevisionEntity, root: 'revisions'
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          []
        end
      end

      namespace :element_revisions do
        desc 'list Generic Element Revisions'
        params do
          requires :id, type: Integer, desc: 'Generic Element Id'
        end
        get do
          list = element_revisions(params)
          present list, with: Labimotion::ElementRevisionEntity, root: 'revisions'
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          []
        end
      end

      namespace :delete_klass_revision do
        desc 'delete Klass Revision'
        params do
          requires :id, type: Integer, desc: 'Revision ID'
          requires :klass_id, type: Integer, desc: 'Klass ID'
          requires :klass, type: String, desc: 'Klass', values: %w[ElementKlass SegmentKlass DatasetKlass]
        end
        post do
          authenticate_admin!(params[:klass].gsub(/(Klass)/, 's').downcase)
          delete_klass_revision(params)
          status 201
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          raise e
        end
      end

      namespace :delete_revision do
        desc 'delete Generic Element Revisions'
        params do
          requires :id, type: Integer, desc: 'Revision Id'
          requires :element_id, type: Integer, desc: 'Element ID'
          requires :klass, type: String, desc: 'Klass', values: %w[Element Segment Dataset]
        end
        post do
          delete_revision(params)
          status 201
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          raise e
        end
      end

      namespace :segment_revisions do
        desc 'list Generic Element Revisions'
        params do
          optional :id, type: Integer, desc: 'Generic Element Id'
        end
        get do
          klass = Labimotion::Segment.find(params[:id])
          list = klass.segments_revisions unless klass.nil?
          present list&.order(created_at: :desc)&.limit(10), with: Labimotion::SegmentRevisionEntity, root: 'revisions'
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          []
        end
      end

      namespace :upload_generics_files do
        desc 'upload generic files'
        params do
          requires :att_id, type: Integer, desc: 'Element Id'
          requires :att_type, type: String, desc: 'Element Type'
        end
        after_validation do
          if params[:att_type] == 'Sample' || params[:att_type] == 'Reaction' || params[:att_type] == 'ResearchPlan'
            el = "#{params[:att_type]}".constantize.find_by(id: params[:att_id])
          else
            el = "Labimotion::#{params[:att_type]}".constantize.find_by(id: params[:att_id])
          end
          error!('401 Unauthorized', 401) if el.nil?

          policy_updatable = ElementPolicy.new(current_user, el).update?
          error!('401 Unauthorized', 401) unless policy_updatable
        end
        post do
          upload_generics_files(current_user, params)
          true
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          raise e
        end
      end

      namespace :list_element_klass do
        desc 'list Generic Element Klass'
        params do
          optional :is_generic, type: Boolean, desc: 'Is Generic or Non-Generic Element'
          optional :is_active, type: Boolean, desc: 'Active or Inactive'
          optional :displayed_in_list, type: Boolean, desc: 'Display in list format', default: true
        end
        get do
          scope = params[:displayed_in_list] ? Labimotion::ElementKlass.for_list_display : Labimotion::ElementKlass.all
          scope = scope.where(is_generic: params[:is_generic]) if params.key?(:is_generic)
          scope = scope.where(is_active: params[:is_active]) if params.key?(:is_active)

          list = scope.sort_by(&:place)
          present list, with: Labimotion::ElementKlassEntity, root: 'klass', displayed_in_list: params[:displayed_in_list]
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          raise e
        end
      end

      # Deprecated: This namespace is no longer used, but kept for backward compatibility.
      namespace :klasses_all do
        desc 'get all klasses for admin function'
        get do
          list = Labimotion::ElementKlass.all.sort_by { |e| e.place }
          present list, with: Labimotion::ElementKlassEntity, root: 'klass'
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          []
        end
      end

      namespace :fetch_repo do
        desc 'fetch Generic Element Klass from Chemotion Repository'
        get do
          fetch_repo('ElementKlass', current_user)
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          []
        end
      end

      namespace :create_repo_klass do
        desc 'create Generic Element Klass'
        params do
          requires :identifier, type: String, desc: 'Identifier'
        end
        post do
          msg = create_repo_klass(params, current_user, request.headers['Origin'])
          klass = Labimotion::ElementKlassEntity.represent(Labimotion::ElementKlass.all)
          { status: msg[:status], message: msg[:message], klass: klass }
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          { error: e.message }
        end
      end

      namespace :de_activate_klass do
        desc 'activate or deactivate Generic Klass'
        params do
          requires :klass, type: String, desc: 'Klass', values: %w[ElementKlass SegmentKlass DatasetKlass]
          requires :id, type: Integer, desc: 'Klass ID'
          requires :is_active, type: Boolean, desc: 'Active or Inactive Klass'
        end
        after_validation do
          authenticate_admin!(params[:klass].gsub(/(Klass)/, 's').downcase)
          fetch_klass(params[:klass], params[:id])
        end
        post do
          deactivate_klass(params)
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          raise e
        end
      end

      namespace :delete_klass do
        desc 'delete Generic Klass'
        params do
          requires :klass, type: String, desc: 'Klass', values: %w[ElementKlass SegmentKlass DatasetKlass]
          requires :id, type: Integer, desc: 'Klass ID'
        end
        delete ':id' do
          delete_klass(params)
          status 201
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          raise e
        end
      end

      namespace :update_template do
        desc 'update Generic Properties Template'
        params do
          requires :klass, type: String, desc: 'Klass', values: %w[ElementKlass SegmentKlass DatasetKlass]
          requires :id, type: Integer, desc: 'Klass ID'
          requires :properties_template, type: Hash
          optional :metadata, type: Hash, default: {}
          optional :release, type: String, default: 'draft', desc: 'release status', values: %w[draft major minor patch]
        end
        after_validation do
          authenticate_admin!(params[:klass].gsub(/(Klass)/, 's').downcase)
          fetch_klass(params[:klass], params[:id])
        end
        post do
          update_template(params, current_user)
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          raise e
        end
      end

      namespace :upload_klass do
        desc 'upload Generic Klass'
        params do
          use :upload_element_klass_params
        end
        post do
          declared_params = declared(params, include_missing: false)
          attributes = declared_params.merge(
              created_by: current_user.id,
              released_by: current_user.id,
              updated_by: current_user.id,
              is_active: false
            )
            validate_klass(attributes)
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          raise e
        end
      end

      namespace :split do
        desc 'split elements'
        params do
          requires :ui_state, type: Hash, desc: 'Selected elements from the UI'
        end
        post do
          split_elements(params[:ui_state], current_user)
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          { error: e.message }
        end
      end

      desc 'Return serialized elements of current user'
      params do
        optional :collection_id, type: Integer, desc: 'Collection id'
        optional :el_type, type: String, desc: 'element klass name'
        optional :from_date, type: Integer, desc: 'created_date from in ms'
        optional :to_date, type: Integer, desc: 'created_date to in ms'
        optional :user_label, type: Integer, desc: 'user label'
        optional :filter_created_at, type: Boolean, desc: 'filter by created at or updated at'
        optional :sort_column, type: String, desc: 'sort by updated_at or selected layers property'
      end
      paginate per_page: 7, offset: 0, max_per_page: 100
      get do
        scope = list_serialized_elements(params, current_user)
        reset_pagination_page(scope)
        generic_elements = paginate(scope).map do |element|
          Labimotion::ElementEntity.represent(
            element,
            displayed_in_list: true,
            detail_levels: ElementDetailLevelCalculator.new(user: current_user, element: element).detail_levels,
          )
        end
        { generic_elements: generic_elements }
      rescue StandardError => e
        Labimotion.log_exception(e, current_user)
        { generic_elements: [] }
      end

      desc 'Return serialized element by id'
      params do
        requires :id, type: Integer, desc: 'Element id'
      end
      route_param :id do
        before do
          @element_policy = ElementPolicy.new(current_user, Labimotion::Element.find(params[:id]))
          error!('401 Unauthorized', 401) unless current_user.matrix_check_by_name('genericElement') && @element_policy.read?
        rescue ActiveRecord::RecordNotFound
          error!('404 Not Found', 404)
        end

        get do
          element = Labimotion::Element.find(params[:id])
          {
            element: Labimotion::ElementEntity.represent(
              element,
              detail_levels: ElementDetailLevelCalculator.new(user: current_user, element: element).detail_levels,
              policy: @element_policy
            ),
            attachments: Entities::AttachmentEntity.represent(element&.attachments)
          }
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
        end
      end

      desc 'Create a element'
      params do
        use :create_element_params
      end
      post do
        begin
          element = create_element(current_user, params)
          present(
            element,
            with: Labimotion::ElementEntity,
            root: :element,
            detail_levels: ElementDetailLevelCalculator.new(user: current_user, element: element).detail_levels,
          )
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          raise e
        end
      end

      desc 'Update element by id'
      params do
        use :update_element_params
      end
      route_param :id do
        before do
          error!('401 Unauthorized', 401) unless ElementPolicy.new(current_user, Labimotion::Element.find(params[:id])).update?
        end

        put do
          begin
            element = update_element_by_id(current_user, params)
            {
              element: Labimotion::ElementEntity.represent(
                element,
                detail_levels: ElementDetailLevelCalculator.new(user: current_user, element: element).detail_levels,
              ),
              attachments: Entities::AttachmentEntity.represent(element&.attachments),
            }
          rescue StandardError => e
            Labimotion.log_exception(e, current_user)
            raise e
          end
        end
      end
    end
  end

  # Entity for element lookup by name response
  class ElementLookupEntity < Grape::Entity
    expose :id
    expose :name
    expose :short_label do |element|
      element.respond_to?(:short_label) ? element.short_label : nil
    end
    expose :element_klass_id, as: :element_klass_id do |element|
      element.element_klass&.id
    end
    expose :klass_label, as: :klass_label do |element|
      element.element_klass&.label
    end
    expose :klass_name, as: :klass_name do |element|
      element.element_klass&.name
    end
    expose :klass_icon, as: :klass_icon do |element|
      element.element_klass&.icon_name
    end
  end
end
