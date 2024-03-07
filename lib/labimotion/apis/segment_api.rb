module Labimotion
  class SegmentAPI < Grape::API
    include Grape::Kaminari
    helpers Labimotion::GenericHelpers
    helpers Labimotion::SegmentHelpers
    helpers Labimotion::ParamHelpers

    resource :segments do
      namespace :klasses do
        desc "get segment klasses"
        params do
          optional :element, type: String, desc: "Klass Element, e.g. Sample, Reaction, Mof,..."
        end
        get do
          list = klass_list(params[:element], true)
          present list, with: Labimotion::SegmentKlassEntity, root: 'klass'
        end
      end

      namespace :list_segment_klass do
        desc 'list Generic Segment Klass'
        params do
          optional :is_active, type: Boolean, desc: 'Active or Inactive Segment'
        end
        get do
          list = klass_list(nil, params[:is_active])
          present list, with: Labimotion::SegmentKlassEntity, root: 'klass'
        end
      end

      namespace :create_segment_klass do
        desc 'create Generic Segment Klass'
        params do
          use :create_segment_klass_params
        end
        after_validation do
          authenticate_admin!('segments')
          @klass = fetch_klass('ElementKlass', params[:element_klass])
        end
        post do
          create_segment_klass(current_user, params)
        rescue ActiveRecord::RecordInvalid => e
          { error: e.message }
        end
      end

      namespace :update_segment_klass do
        desc 'update Generic Segment Klass'
        params do
          use :update_segment_klass_params
        end
        after_validation do
          authenticate_admin!('segments')
        end
        post do
          update_segment_klass(current_user, params)
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          { error: e.message }
        end
      end

      namespace :fetch_repo_generic_template do
        desc 'fetch segment templates from repository'
        params do
          requires :identifier, type: String, desc: 'identifier'
        end
        post do
          sk_obj = fetch_repo_generic_template('Segment', params[:identifier])
          sk_obj = sk_obj.deep_symbolize_keys[:generic_template]
          return { error: 'No template data found' } unless sk_obj.present?

          ek_obj = Labimotion::ElementKlass.find_by(name: sk_obj.dig(:element_klass, :klass_name))
          return { error: 'No related element data found' } unless ek_obj.present?

          segment_klass = Labimotion::SegmentKlass.find_or_create_by(
            identifier: sk_obj.dig(:identifier),
          )
          segment_klass.update(sk_obj.slice(
            :label,
            :desc,
            :place,
            :properties_release,
            :uuid,
          ).merge(
            is_active: true,
            properties_template: sk_obj.dig(:properties_release), # properties_release,
            element_klass: ek_obj,
            created_by: current_user.id,
            released_at: DateTime.now,
            sync_time: DateTime.now,
          ))

          present segment_klass, with: Labimotion::SegmentKlassEntity, root: 'klass'
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          { error: e.message }
        end
      end

      namespace :fetch_repo_generic_template_list do
        desc 'fetch segment templates from repository'
        get do
          fetch_repo_generic_template_list('Segment')
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          { error: e.message }
        end
      end

      namespace :fetch_repo do
        desc 'fetch Generic Segment Klass from Chemotion Repository'
        get do
          fetch_repo('SegmentKlass', current_user)
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          { error: e.message }
        end
      end

      namespace :create_repo_klass do
        desc 'create Generic Segment Klass'
        params do
          requires :identifier, type: String, desc: 'Identifier'
        end
        post do
          msg = create_repo_klass(params, current_user, request.headers['Origin'])
          klass = Labimotion::SegmentKlassEntity.represent(SegmentKlass.all)
          { status: msg[:status], message: msg[:message], klass: klass }
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          ## { error: e.message }
          raise e
        end
      end

      namespace :upload_klass do
        desc 'upload Generic Klass'
        params do
          use :upload_segment_klass_params
        end
        post do
          declared_params = declared(params, include_missing: false)
          attributes = declared_params.merge(
              created_by: current_user.id,
              released_by: current_user.id,
              updated_by: current_user.id,
              is_active: false
            )
          attr_klass = params['element_klass'] || {}
          attributes.delete(:element_klass)
          validate_klass(attributes, attr_klass)
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          raise e
        end
      end
    end
  end
end
