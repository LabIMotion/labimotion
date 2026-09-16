# frozen_string_literal: true

require 'labimotion/version'
require 'labimotion/libs/export_element'
require 'labimotion/helpers/mtt_helpers'
require 'labimotion/models/dose_resp_output'

module Labimotion
  # Generic Element API
  class MttAPI < Grape::API
    helpers Labimotion::ParamHelpers
    helpers Labimotion::MttHelpers

    namespace :public do
      resource :mtt_apps do
        route_param :token do
          desc 'Download data from MTT app (GET endpoint)'
          get do
            download_json_to_external_app
          end

          desc 'Upload modified data from MTT app (POST endpoint)'
          post do
            upload_json_from_external_app
          end
        end
      end
    end

    resource :mtt do
      namespace :requests do
        desc 'Get MTT requests for current user, scoped to a single element'
        params do
          requires :element_id, type: Integer, desc: 'Only return requests for this element'
        end
        get do
          # Get requests created by current user for the selected element only
          requests = Labimotion::DoseRespRequest
                     .includes(:dose_resp_outputs)
                     .where(created_by: current_user.id, element_id: params[:element_id])
                     .order(created_at: :desc)

          # Return formatted response
          requests.map { |req| mtt_request_json(req, include_outputs: true) }
        end

        desc 'Delete one or multiple MTT requests'
        params do
          requires :ids, type: Array[Integer], desc: 'Array of request IDs to delete'
        end
        delete do
          # Find requests belonging to current user
          requests = Labimotion::DoseRespRequest.where(
            id: params[:ids],
            created_by: current_user.id
          )

          if requests.empty?
            error!('No requests found or unauthorized', 404)
          end

          deleted_count = requests.count
          requests.destroy_all

          {
            success: true,
            message: "Successfully deleted #{deleted_count} request(s)",
            deleted_count: deleted_count
          }
        rescue StandardError => e
          error!("Error deleting requests: #{e.message}", 500)
        end

        desc 'Update MTT request'
        params do
          requires :id, type: Integer, desc: 'Request ID'
          optional :state, type: Integer, desc: 'State (-1: error, 0: initial, 1: processing, 2: completed)', values: [-1, 0, 1, 2]
          optional :resp_message, type: String, desc: 'Response message'
          optional :wellplates_metadata, type: Hash, desc: 'Wellplates metadata'
          optional :input_metadata, type: Hash, desc: 'Input metadata'
          optional :revoked, type: Boolean, desc: 'Revoke access token'
        end
        patch ':id' do
          # Find request belonging to current user
          request = Labimotion::DoseRespRequest.find_by(
            id: params[:id],
            created_by: current_user.id
          )

          error!('Request not found or unauthorized', 404) unless request

          # Prepare update attributes
          update_attrs = {}
          update_attrs[:state] = params[:state] if params.key?(:state)
          update_attrs[:resp_message] = params[:resp_message] if params.key?(:resp_message)
          update_attrs[:wellplates_metadata] = params[:wellplates_metadata] if params.key?(:wellplates_metadata)
          update_attrs[:input_metadata] = params[:input_metadata] if params.key?(:input_metadata)
          update_attrs[:revoked_at] = params[:revoked] ? Time.current : nil if params.key?(:revoked)

          if request.update(update_attrs)
            {
              success: true,
              message: 'Request updated successfully',
              request: {
                id: request.id,
                request_id: request.request_id,
                state: request.state,
                state_name: mtt_state_name(request.state),
                resp_message: request.resp_message,
                revoked: request.revoked?,
                updated_at: request.updated_at
              }
            }
          else
            error!("Validation error: #{request.errors.full_messages.join(', ')}", 422)
          end
        rescue ActiveRecord::RecordNotFound
          error!('Request not found', 404)
        rescue StandardError => e
          error!("Error updating request: #{e.message}", 500)
        end
      end

      namespace :outputs do
        desc 'Delete one or multiple MTT outputs'
        params do
          requires :ids, type: Array[Integer], desc: 'Array of output IDs to delete'
        end
        delete do
          # Find outputs where the parent request belongs to current user
          outputs = Labimotion::DoseRespOutput
                    .joins(:dose_resp_request)
                    .where(
                      id: params[:ids],
                      dose_resp_requests: { created_by: current_user.id }
                    )

          if outputs.empty?
            error!('No outputs found or unauthorized', 404)
          end

          deleted_count = outputs.count
          outputs.destroy_all

          {
            success: true,
            message: "Successfully deleted #{deleted_count} output(s)",
            deleted_count: deleted_count
          }
        rescue StandardError => e
          error!("Error deleting outputs: #{e.message}", 500)
        end

        desc 'Delete a single result (by sample name) from an output'
        params do
          requires :id, type: Integer, desc: 'Output ID'
          requires :sample_name, type: String, desc: 'Sample name (result[].name) to remove'
        end
        delete ':id/results' do
          # Only operate on outputs whose parent request belongs to the current user
          output = Labimotion::DoseRespOutput
                   .joins(:dose_resp_request)
                   .where(dose_resp_requests: { created_by: current_user.id })
                   .find_by(id: params[:id])

          error!('Output not found or unauthorized', 404) unless output

          outcome = remove_mtt_result_by_sample_name(output, params[:sample_name])
          error!('Result not found in output', 404) unless outcome[:removed]

          {
            success: true,
            message: "Removed result '#{params[:sample_name]}' from output #{params[:id]}",
            output_id: params[:id],
            output_deleted: outcome[:output_deleted],
            output: outcome[:output_deleted] ? nil : mtt_output_json(output)
          }
        rescue StandardError => e
          error!("Error deleting result: #{e.message}", 500)
        end
      end

      namespace :create_mtt_request do
        desc 'Create MTT assay request'
        params do
          use :create_mtt_request_params
        end
        post do
          # Find element and wellplates
          element = Labimotion::Element.find_by(id: params[:id])
          error!('Element not found', 404) unless element

          # Verify user has update permission
          error!('Unauthorized', 403) unless ElementPolicy.new(current_user, element).update?

          wellplates = Wellplate.where(id: params[:wellplate_ids])
          error!('No wellplates found', 404) if wellplates.empty?

          # Generate wellplates metadata
          wellplates_metadata = generate_wellplates_metadata(wellplates)

          # Create DoseRespRequest record with token
          dose_resp_request = Labimotion::DoseRespRequest.create!(
            element_id: element.id,
            wellplates_metadata: { wellplates: wellplates_metadata },
            input_metadata: {
              wellplate_ids: params[:wellplate_ids],
              element_id: element.id,
              element_name: element.name,
              created_at: Time.current
            },
            state: Labimotion::DoseRespRequest::STATE_INITIAL,
            created_by: current_user&.id,
            expires_at: TPA_EXPIRATION.from_now
          )

          # Generate external app URL with token
          token_uri = token_url(dose_resp_request)
          external_app_url = get_external_app_url

          # Format: "#{@app.url}?url=#{CGI.escape(token_uri)}&type=ThirdPartyApp"
          "#{external_app_url}?method=DoseResponse&url=#{CGI.escape(token_uri)}"
        rescue ActiveRecord::RecordInvalid => e
          error!("Validation error: #{e.message}", 422)
        rescue ActiveRecord::RecordNotFound => e
          error!("Not found: #{e.message}", 404)
        rescue StandardError => e
          error!("Error: #{e.message}", 500)
        end
      end
    end
  end
end
