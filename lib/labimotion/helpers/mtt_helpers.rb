# frozen_string_literal: true

require 'grape'
require 'net/http'
require 'uri'
require 'zip'

module Labimotion
  ## MTT Helpers
  module MttHelpers
    extend Grape::API::Helpers

    TPA_EXPIRATION = 72.hours

    def token_url(dose_resp_request)
      # Build the callback URL with token in path
      api_base_url = ENV['PUBLIC_URL'] || 'http://172.28.156.100:3000'
      callback_path = "/api/v1/public/mtt_apps/#{dose_resp_request.access_token}"
      callback_url = "#{api_base_url}#{callback_path}"

      callback_url
    end

    def get_external_app_url
      ENV['MTT_EXTERNAL_APP_URL'] || 'http://localhost:4050'
    end

    # --- Serialization helpers (shared across the MTT request endpoints) ---

    def mtt_state_name(state)
      case state
      when Labimotion::DoseRespRequest::STATE_ERROR then 'error'
      when Labimotion::DoseRespRequest::STATE_INITIAL then 'initial'
      when Labimotion::DoseRespRequest::STATE_PROCESSING then 'processing'
      when Labimotion::DoseRespRequest::STATE_COMPLETED then 'completed'
      else 'unknown'
      end
    end

    def mtt_output_json(output)
      {
        id: output.id,
        output_data: output.output_data,
        notes: output.notes,
        created_at: output.created_at
      }
    end

    def mtt_request_json(req, include_outputs: false)
      json = {
        id: req.id,
        request_id: req.request_id,
        element_id: req.element_id,
        state: req.state,
        state_name: mtt_state_name(req.state),
        created_at: req.created_at,
        expires_at: req.expires_at,
        expired: req.expired?,
        revoked: req.revoked?,
        active: req.active?,
        resp_message: req.resp_message,
        last_accessed_at: req.last_accessed_at,
        access_count: req.access_count || 0
      }
      json[:outputs] = req.dose_resp_outputs.map { |output| mtt_output_json(output) } if include_outputs
      json
    end

    # The sample name of a result node, i.e. result[0].name. Used to match a
    # single result row across both output_data shapes (see below). JSONB columns
    # deserialize with string keys; symbol keys are tolerated defensively.
    def mtt_result_name(node)
      return nil unless node.is_a?(Hash)

      result = node['result'] || node[:result]
      return nil unless result.is_a?(Array) && result.first.is_a?(Hash)

      result.first['name'] || result.first[:name]
    end

    # Remove a single result row (matched by sample name) from an output's
    # output_data JSON, supporting both the new (Output[].items[]) and the legacy
    # (Output[].result[]) shapes. If the output has no results left afterwards the
    # record is soft-deleted (acts_as_paranoid), consistent with the bulk delete.
    #
    # Returns { removed:, output_deleted: }.
    def remove_mtt_result_by_sample_name(output, sample_name)
      data = output.output_data || {}
      groups = data['Output'] || data[:Output]
      return { removed: false, output_deleted: false } unless groups.is_a?(Array)

      removed = false
      new_groups = groups.map do |group|
        items = group['items'] || group[:items]
        if items.is_a?(Array)
          # New structure: drop the matching item(s) from the group.
          kept = items.reject { |item| mtt_result_name(item) == sample_name }
          removed ||= kept.length != items.length
          kept.empty? ? nil : group.merge('items' => kept)
        elsif mtt_result_name(group) == sample_name
          # Legacy structure: drop the whole group.
          removed = true
          nil
        else
          group
        end
      end.compact

      return { removed: false, output_deleted: false } unless removed

      if new_groups.empty?
        output.destroy
        { removed: true, output_deleted: true }
      else
        output.update!(output_data: data.merge('Output' => new_groups))
        { removed: true, output_deleted: false }
      end
    end

    def validate_token(token)
      # Find the request by access token
      request = Labimotion::DoseRespRequest.find_by(access_token: token)
      error!('Token not found', 404) unless request

      # Check expiration
      error!('Token expired', 403) if request.expired?

      # Check revocation
      error!('Token revoked', 403) if request.revoked?

      request
    end

    def validate_user_access(dose_resp_request)
      # Get element and user
      element = dose_resp_request.element
      error!('Element not found', 404) unless element

      user = dose_resp_request.creator
      error!('User not found', 404) unless user

      # Check user has update permission on element using ElementPolicy
      policy = ElementPolicy.new(user, element)
      error!('Unauthorized', 403) unless policy.update?

      { element: element, user: user }
    end

    def download_json_to_external_app
      # Get token from route params
      token = params[:token]
      dose_resp_request = validate_token(token)

      # Validate user access
      validate_user_access(dose_resp_request)

      # Track access and update state
      # dose_resp_request.track_access!
      dose_resp_request.mark_processing! if dose_resp_request.state == Labimotion::DoseRespRequest::STATE_INITIAL
      # Return wellplates metadata as JSON
      # Access the wellplates array from the metadata structure
      wellplates_data = dose_resp_request.wellplates_metadata&.dig('wellplates') ||
                        dose_resp_request.wellplates_metadata&.dig(:wellplates) ||
                        []

      response_data = {
        id: dose_resp_request.id.to_s,
        request_id: dose_resp_request.request_id,
        element_info: extract_element_properties(dose_resp_request.element),
        wellplates: wellplates_data
      }

      status 200
      response_data
    rescue => e
      error!("Error: #{e.message}", 500)
    end

    def upload_json_from_external_app
      # Get token from route params
      token = params[:token]
      dose_resp_request = validate_token(token)

      # Validate user access
      access_info = validate_user_access(dose_resp_request)
      user = access_info[:user]
      element = access_info[:element]
      # Handle file upload
      file_param = params['file'] || params[:file]
      error!('No file uploaded', 400) unless file_param && file_param.is_a?(Hash) && file_param['tempfile']

      tempfile = file_param['tempfile']
      filename = file_param['filename'] || 'upload'
      # Check if it's a zip file
      if filename.end_with?('.zip')
        # Process zip file
        wellplates_data, csv_data = process_zip_file(tempfile)

        error!('Missing JSON data in zip file', 400) unless wellplates_data

        # Create analysis container and dataset with CSV if present
        # if csv_data
        #   create_analysis_with_csv(element, user, csv_data, dose_resp_request, wellplates_data)
        # end
      # else
      #   # Handle single JSON file
      #   file_content = tempfile.read
      #   tempfile.rewind
      #   json_data = JSON.parse(file_content).with_indifferent_access
      #   wellplates_data = json_data[:Output]

      #   error!('Missing wellplates data', 400) unless wellplates_data
      end

      dose_resp_request.track_access!

      # Save output data to dose_resp_outputs table
      output = dose_resp_request.dose_resp_outputs.create!(
        output_data: { Output: wellplates_data }
      )
      if csv_data
        create_analysis_with_csv(element, user, csv_data, dose_resp_request, output)
      end

      dose_resp_request.update!(
        wellplates_metadata: { wellplates: wellplates_data },
        resp_message: 'Data updated successfully'
      )

      # Mark as completed
      dose_resp_request.mark_completed!

      status 200
      {
        success: true,
        message: 'Data updated successfully',
        request_id: dose_resp_request.id
      }
    rescue JSON::ParserError => e
      error!("Invalid JSON: #{e.message}", 400)
    rescue ActiveRecord::RecordInvalid => e
      dose_resp_request.mark_error!(e.message) if dose_resp_request
      error!("Validation error: #{e.message}", 422)
    rescue => e
      dose_resp_request.mark_error!(e.message) if dose_resp_request
      error!("Error: #{e.message}", 500)
    end

    def process_zip_file(tempfile)
      wellplates_data = nil
      csv_data = nil

      Zip::File.open(tempfile.path) do |zip_file|
        zip_file.each do |entry|
          if entry.name.end_with?('.json')
            # Read JSON file
            json_content = entry.get_input_stream.read
            json_data = JSON.parse(json_content).with_indifferent_access
            wellplates_data = json_data[:Output]
          elsif entry.name.end_with?('.xls', '.xlsx', '.csv')
            # Read CSV/Excel file - extract just the basename without path
            csv_content = entry.get_input_stream.read
            csv_data = {
              filename: File.basename(entry.name),
              content: csv_content
            }
          end
        end
      end

      [wellplates_data, csv_data]
    end

    def create_analysis_with_csv(element, user, csv_data, dose_resp_request, output)
      analysis, dataset = create_analysis_with_dataset(
        element: element,
        analysis_name: "MTT Analysis #{dose_resp_request.request_id}-#{output&.id}",
        dataset_name: 'new',
        analysis_attributes: {}
      )

      # Determine content type based on file extension
      content_type = case File.extname(csv_data[:filename]).downcase
                     when '.xlsx'
                       'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
                     when '.xls'
                       'application/vnd.ms-excel'
                     when '.csv'
                       'text/csv'
                     else
                       'application/octet-stream'
                     end

      # Create a temporary file for the attachment
      temp_file = Tempfile.new([File.basename(csv_data[:filename], '.*'), File.extname(csv_data[:filename])])
      begin
        temp_file.binmode
        temp_file.write(csv_data[:content])
        temp_file.rewind

        # Create attachment for CSV/Excel file
        attachment = Attachment.new(
          filename: csv_data[:filename],
          file_path: temp_file.path,
          created_by: user.id,
          created_for: user.id,
          attachable_type: 'Container',
          attachable_id: dataset.id,
          content_type: content_type
        )
        attachment.save! if attachment.valid?

        { analysis: analysis, dataset: dataset, attachment: attachment }
      ensure
        temp_file.close
        temp_file.unlink
      end
    end

    def create_analysis_with_dataset(
      element:,
      analysis_name: 'New Analysis',
      dataset_name: 'New Dataset',
      analysis_attributes: {}
    )
      # Ensure the element has a root container
      ensure_root_container(element)

      # Get or create the analyses container
      analyses_container = element.container.children.find_or_create_by(container_type: 'analyses')

      # Prepare default extended_metadata for analysis
      default_metadata = {
        'content' => '{"ops":[{"insert":""}]}',
        'report' => true
      }
      extended_metadata = default_metadata.merge(analysis_attributes[:extended_metadata] || {})

      # Create the analysis container
      analysis_container = analyses_container.children.create(
        container_type: 'analysis',
        name: analysis_name,
        description: analysis_attributes[:description] || '',
        extended_metadata: extended_metadata
      )

      # Create the dataset container nested under the analysis
      dataset_container = analysis_container.children.create(
        container_type: 'dataset',
        name: dataset_name,
        description: '',
        extended_metadata: {}
      )

      [analysis_container, dataset_container]
    end

    def ensure_root_container(element)
      return if element.container.present?

      element.container = Container.create_root_container
    end
    # def send_mtt_request(current_user, params)

    #   token_uri = token_url(current_user, params)


    #   uri = URI.parse(api_url)
    #   http = Net::HTTP.new(uri.host, uri.port)
    #   http.use_ssl = (uri.scheme == 'https')
    #   http.read_timeout = 30

    #   # Ensure path is not empty, default to '/' if needed
    #   path = uri.path.empty? ? '/' : uri.path
    #   request = Net::HTTP::Post.new(path, { 'Content-Type' => 'application/json' })
    #   request.body = json_data.to_json

    #   response = http.request(request)

    #   {
    #     success: response.is_a?(Net::HTTPSuccess),
    #     status: response.code,
    #     body: (JSON.parse(response.body) rescue response.body),
    #     message: response.message
    #   }
    # rescue StandardError => e
    #   {
    #     success: false,
    #     error: e.message,
    #     backtrace: e.backtrace.first(5)
    #   }
    # end

    def extract_readout_titles(wellplate)
      # Extract readout titles from wellplate
      if wellplate.respond_to?(:readout_titles)
        titles = wellplate.readout_titles
        return titles if titles.is_a?(Array)
        return JSON.parse(titles) if titles.is_a?(String)
      end
      []
    end

    def extract_wells(wellplate)
      # Extract wells data from wellplate
      wells = wellplate.wells || []
      wells.map do |well|
        # Position might be stored as a hash or separate fields
        position = if well.respond_to?(:position) && well.position.is_a?(Hash)
                     well.position
                   elsif well.respond_to?(:position_x)
                     { x: well.position_x, y: well.position_y }
                   else
                     { x: 0, y: 0 }
                   end

        well_data = {
          id: well.id,
          position: position
        }

        # Only include readouts if they have values
        readouts = extract_readouts(well)
        well_data[:readouts] = readouts if readouts.present?

        # Only include sample if it exists
        sample = extract_sample(well)
        well_data[:sample] = sample if sample.present?

        well_data
      end
    end

    def extract_readouts(well)
      # Extract readouts from well
      # Readouts are typically stored as JSON data in the well
      readouts = if well.respond_to?(:readouts) && well.readouts.is_a?(Array)
                   well.readouts
                 elsif well.respond_to?(:readouts) && well.readouts.is_a?(String)
                   JSON.parse(well.readouts) rescue []
                 elsif well.respond_to?(:readouts) && well.readouts.is_a?(Hash)
                   well.readouts.values rescue []
                 else
                   []
                 end

      # Filter out empty readouts (both unit and value are blank)
      readouts.select do |readout|
        readout.is_a?(Hash) &&
        (readout['unit'].to_s.present? || readout['value'].to_s.present? ||
         readout[:unit].to_s.present? || readout[:value].to_s.present?)
      end
    end

    def extract_sample(well)
      # Extract sample information from well
      if well.respond_to?(:sample) && well.sample.present?
        sample = well.sample
        return {
          id: sample.id,
          short_label: sample.short_label,
          conc: sample.try(:molarity_value) || 0
        }
      end
      nil
    end

    def generate_wellplates_metadata(wellplates)
      wellplates.map do |wellplate|
        {
          id: wellplate.id.to_s,
          readoutTitles: extract_readout_titles(wellplate),
          wells: extract_wells(wellplate)
        }
      end
    end

    def extract_element_properties(element)
      props = {
        id: element.id.to_s,
        name: element.name
      }

      layers = element.properties.dig('layers', 'general_information', 'fields') ||
               element.properties.dig(:layers, :general_information, :fields) || []

      endpoint_field = layers.find { |f| f['field'] == 'Endpoint' || f[:field] == 'Endpoint' }
      props[:endpoint] = endpoint_field['value'] || endpoint_field[:value] if endpoint_field

      props
    end


    def generate_element_metadata(element)
      {
        id: wellplate.id.to_s,
        readoutTitles: extract_readout_titles(wellplate),
        wells: extract_wells(wellplate)
      }
    end


    def generate_json_data(wellplates)
      # # Generate wellplates metadata
      wellplates_metadata = generate_wellplates_metadata(wellplates)

      # Generate JSON structure
      json_data = {
        id: element.id.to_s,
        request_id: dose_resp_request.id.to_s,
        wellplates: wellplates_metadata
      }
      # Save to JSON file
      filename = "mtt_request_#{element.id}_#{dose_resp_request.id}.json"
      filepath = Rails.root.join('tmp', filename)
      File.write(filepath, JSON.pretty_generate(json_data))
      json_data
    end
  end
end
