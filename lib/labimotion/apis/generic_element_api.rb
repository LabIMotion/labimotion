# frozen_string_literal: true

require 'labimotion/version'
require 'labimotion/libs/export_element'

module Labimotion
  # Generic Element API
  class GenericElementAPI < Grape::API
    include Grape::Kaminari
    helpers ContainerHelpers
    helpers ParamsHelpers
    helpers CollectionHelpers
    helpers Labimotion::SampleAssociationHelpers
    helpers Labimotion::GenericHelpers
    helpers Labimotion::ElementHelpers
    helpers Labimotion::ParamHelpers

    resource :generic_elements do
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
          filename = URI.escape(el_filename)
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
          present list&.sort_by(&:created_at).reverse, with: Labimotion::SegmentRevisionEntity, root: 'revisions'
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
          klass = Labimotion::ElementKlassEntity.represent(ElementKlass.all)
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
          @klz = fetch_klass(params[:klass], params[:id])
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
          optional :release, type: String, default: 'draft', desc: 'release status', values: %w[draft major minor patch]
        end
        after_validation do
          authenticate_admin!(params[:klass].gsub(/(Klass)/, 's').downcase)
          @klz = fetch_klass(params[:klass], params[:id])
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
        optional :sync_collection_id, type: Integer, desc: 'SyncCollectionsUser id'
        optional :el_type, type: String, desc: 'element klass name'
        optional :from_date, type: Integer, desc: 'created_date from in ms'
        optional :to_date, type: Integer, desc: 'created_date to in ms'
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
          @element_policy = ElementPolicy.new(current_user, Element.find(params[:id]))
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
            attachments: attach_thumbnail(element&.attachments)
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
              attachments: attach_thumbnail(element&.attachments),
            }
          rescue StandardError => e
            Labimotion.log_exception(e, current_user)
            raise e
          end
        end
      end      
    end
  end
end
