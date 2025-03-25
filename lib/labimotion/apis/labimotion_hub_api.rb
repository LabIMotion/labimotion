# frozen_string_literal: true

require 'open-uri'
require 'labimotion/models/hub_log'

# Belong to Chemotion module
module Labimotion
  # API for Public data
  class LabimotionHubAPI < Grape::API
    include Grape::Kaminari

    namespace :labimotion_hub do
      namespace :list do
        desc 'get active generic templates'
        params do
          requires :klass, type: String, desc: 'Klass', values: Labimotion::Constants::Klass::ALL
          optional :with_props, type: Boolean, desc: 'With Properties', default: false
        end
        get do
          list = "Labimotion::#{params[:klass]}".constantize.where(is_active: true).where.not(released_at: nil)
          list = list.where(is_generic: true) if params[:klass] == Labimotion::Constants::Klass::ELEMENT
          Labimotion::GenericPublicEntity.represent(list, displayed: params[:with_props], root: 'list')
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          []
        end
      end
      namespace :fetch do
        desc 'get active generic templates'
        params do
          requires :klass, type: String, desc: 'Klass', values: Labimotion::Constants::Klass::ALL
          requires :origin, type: String, desc: 'origin'
          requires :identifier, type: String, desc: 'Identifier'
        end
        post do
          entity = "Labimotion::#{params[:klass]}".constantize.find_by(identifier: params[:identifier])
          Labimotion::HubLog.create(klass: entity, origin: params[:origin], uuid: entity.uuid, version: entity.version)
          "Labimotion::#{params[:klass]}Entity".constantize.represent(entity)
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          raise e
        end
      end

      namespace :element_klasses_name do
        desc 'get klasses'
        params do
          optional :generic_only, type: Boolean, desc: 'list generic element only'
        end
        get do
          if params[:generic_only].present? && params[:generic_only] == true
            list = Labimotion::ElementKlass.where(is_active: true, is_generic: true)
          else
            list = Labimotion::ElementKlass.where(is_active: true)
          end
          list.pluck(:name)
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          []
        end
      end

      namespace :submit do
        desc 'submit a template'
        params do
          requires :klass, type: String, desc: 'klass of the template',
                           values: Labimotion::Constants::Klass::ALL
          requires :id, type: Integer, desc: 'template revision id'
          requires :contact_email, type: String, desc: 'email of the submitter', regexp: URI::MailTo::EMAIL_REGEXP
          requires :application, type: String, desc: 'application for the template'
          requires :message, type: String, desc: 'message of the submission'
        end
        post do
          klass = params[:klass]
          template = "Labimotion::#{klass}esRevision".constantize.find(params[:id])
          klass_data = "Labimotion::#{klass}Entity".constantize.represent(template.klass, displayed_in_list: true)
          metadata = {
            klass: {
              klass: klass,
              data: klass_data
            },
            submission: {
              last_name: current_user.last_name,
              first_name: current_user.first_name,
              email: current_user.email,
              id: current_user.id,
              contact_email: params[:contact_email],
              application: params[:application],
              message: params[:message]
            }
          }

          # Submit the main template
          result = Labimotion::TemplateHub.send_to_central_hub(klass, template.properties_release, metadata,
                                                               request.headers['Origin'])

          # Increment submitted counter if submission was successful
          template.increment_submitted! if result[:mc] == 'ss00'

          # For SegmentKlass, also submit the associated ElementKlass
          if klass == Labimotion::Constants::Klass::SEGMENT && result[:mc] == 'ss00'
            element_klass = template.klass.element_klass
            element_klass_data = Labimotion::ElementKlassEntity.represent(element_klass, displayed_in_list: true)
            element_metadata = {
              klass: {
                klass: Labimotion::Constants::Klass::ELEMENT,
                data: element_klass_data
              },
              submission: metadata[:submission].merge(
                associated_submission_id: result[:data][:id]
              )
            }

            element_result = Labimotion::TemplateHub.send_to_central_hub(Labimotion::Constants::Klass::ELEMENT,
                                                                         element_klass.properties_release,
                                                                         element_metadata, request.headers['Origin'])

            # Increment the ElementKlass revision counter if submission was successful
            if element_result[:mc] == 'ss00'
              # Find the revision that matches the ElementKlass UUID
              element_revision = Labimotion::ElementKlassesRevision.find_by(uuid: element_klass.uuid)
              element_revision&.increment_submitted!
            end
          end

          # Only return the main result; TODO: handle element_result as well
          result
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          { mc: 'se00', msg: e.message, data: [] }
        end
      end
    end
  end
end
