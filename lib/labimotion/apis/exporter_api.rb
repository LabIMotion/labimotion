# frozen_string_literal: true

module Labimotion
  # ExporterAPI handles exporting data to various formats (e.g., XLSX)
  # The class length is justified due to the comprehensive helper methods needed for export functionality
  class ExporterAPI < Grape::API
    include Grape::Kaminari

    helpers Labimotion::ParamHelpers
    helpers Labimotion::ExporterHelpers

    resource :exporter do
      resource :table_xlsx do
        desc 'Export single table field to XLSX format'
        params do
          use :table_xlsx_params
        end
        route_param :id do
          before do
            validate_and_authorize_request!
          end

          get do
            layer = fetch_layer
            field = fetch_field(layer)
            validate_table_field!(field)

            headers, expanded_sub_fields = build_table_headers(field)
            rows = build_table_rows(field, expanded_sub_fields)

            export_to_xlsx(layer, field, headers, rows)
          rescue StandardError => e
            Labimotion.log_exception(e, current_user)
            error!("500 Internal Server Error: #{e.message}", 500)
          end
        end
      end
    end

    # rubocop:disable Metrics/BlockLength
    # The helpers block is necessarily large due to the many specialized helper methods
    # for data fetching, validation, formatting, and export functionality
    helpers do
      # Validate and authorize the request, sets @element instance variable
      def validate_and_authorize_request!
        klass = fetch_klass
        @element = klass.find_by(id: params[:id])

        error!('404 Not Found', 404) if @element.nil?

        authorize_element_access!
      rescue ActiveRecord::RecordNotFound
        error!('404 Not Found', 404)
      rescue NameError => e
        Labimotion.log_exception(e, current_user)
        error!('400 Bad Request - Invalid type', 400)
      end

      # Fetch the element or segment class based on params
      def fetch_klass
        Labimotion::Utils.resolve_class(params[:klass])
      end

      # Authorize element access based on user permissions
      def authorize_element_access!
        element_policy = if params[:klass] == 'Element'
                           ElementPolicy.new(current_user,
                                             @element)
                         else
                           ElementPolicy.new(current_user,
                                             @element.element)
                         end
        matrix_name = params[:klass] == 'Element' ? 'genericElement' : 'segment'

        return if current_user.matrix_check_by_name(matrix_name) && element_policy.read?

        error!('401 Unauthorized', 401)
      end

      # Fetch layer from element properties
      def fetch_layer
        properties = @element.properties
        layers = properties[Labimotion::Prop::LAYERS] || {}
        layer_key = params[:layer_id].to_s
        layer = layers[layer_key]

        error!('404 Layer Not Found', 404) if layer.nil?
        layer
      end

      # Fetch field from layer
      def fetch_field(layer)
        fields = layer[Labimotion::Prop::FIELDS] || []
        field = fields.find { |f| f['field'] == params[:field_id].to_s }

        error!('404 Field Not Found', 404) if field.nil?
        field
      end

      # Validate that the field is a table type
      def validate_table_field!(field)
        return if field['type'] == Labimotion::FieldType::TABLE

        error!('400 Bad Request - Field is not a table type', 400)
      end

      # Build table headers from field definition, expands DRAG_SAMPLE and DRAG_MOLECULE columns
      def build_table_headers(field)
        sub_fields = field.fetch('sub_fields', [])
        headers = []
        expanded_sub_fields = []

        sub_fields.each do |sf|
          base_col_name = normalize_column_name(sf['col_name'])

          if expandable_field?(sf['type'])
            headers, expanded_sub_fields = expand_field_columns(sf, base_col_name, headers, expanded_sub_fields)
          else
            headers << base_col_name
            expanded_sub_fields << sf
          end
        end

        [headers, expanded_sub_fields]
      end

      # Expand field columns for DRAG_SAMPLE and DRAG_MOLECULE with sub-headers
      def expand_field_columns(sub_field, base_col_name, headers, expanded_sub_fields)
        sub_headers = sub_field['value'].to_s.split(';').reject(&:empty?)

        # Always add the base column first (for SVG image link)
        headers << base_col_name
        expanded_sub_fields << sub_field

        # For DRAG_SAMPLE, add base columns for smiles and short_label
        if sub_field['type'] == Labimotion::FieldType::DRAG_SAMPLE
          %w[smiles short_label].each do |base_header|
            headers << base_header
            expanded_sub_fields << {
              'id' => sub_field['id'],
              'type' => sub_field['type'],
              'sub_header' => base_header,
              'original' => sub_field,
              'is_base_column' => true
            }
          end
        end

        # Add extra columns for each sub-header
        sub_headers.each do |sub_header|
          headers << sub_header
          expanded_sub_fields << {
            'id' => sub_field['id'],
            'type' => sub_field['type'],
            'sub_header' => sub_header,
            'original' => sub_field
          }
        end

        [headers, expanded_sub_fields]
      end

      # Build table rows from field data
      def build_table_rows(field, expanded_sub_fields)
        sub_values = field.fetch('sub_values', [])

        sub_values.map do |sub_val|
          expanded_sub_fields.map do |exp_field|
            if exp_field.is_a?(Hash) && exp_field['sub_header']
              format_expanded_cell(sub_val, exp_field)
            else
              format_table_cell(sub_val, exp_field)
            end
          end
        end
      end

      # Export data to XLSX format
      def export_to_xlsx(layer, field, headers, rows)
        element_name = @element.is_a?(Labimotion::Segment) ? @element.element.name : @element.name
        segment_name = @element.is_a?(Labimotion::Segment) ? @element.segment_klass.label : ''
        selected_layer = "#{layer['label'] || ExporterHelpers::CONST_UNNAMED} (#{layer['key']})"
        selected_field = field['label'] || ExporterHelpers::CONST_UNNAMED

        filename = generate_filename(element_name, segment_name, selected_layer, selected_field)
        exporter = Labimotion::XlsxExporter.new(filename)

        worksheet_params = {
          exporter: exporter,
          element_name: element_name,
          layer_name: selected_layer,
          field_name: selected_field,
          headers: headers,
          rows: rows
        }
        worksheet_params[:segment_name] = segment_name unless segment_name.empty?
        populate_worksheet(worksheet_params)

        # Set response headers and format
        configure_xlsx_response(exporter)

        exporter.read
      end

      # Build metadata array for worksheet
      def build_metadata(params)
        metadata = [['Element:', params[:element_name]]]
        metadata << ['Segment:', params[:segment_name]] if params[:segment_name].present?
        metadata.push(
          ['Layer:', params[:layer_name]],
          ['Field:', params[:field_name]],
          ['Exported at:', Time.zone.now.strftime('%Y-%m-%d %H:%M:%S')],
          ['Exported by:', current_user.name]
        )
        metadata
      end

      # Populate worksheet with data
      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def populate_worksheet(params)
        # Store params in local variables for use in the instance_eval block
        table_headers = params[:headers]
        table_rows = params[:rows]
        metadata = build_metadata(params)

        params[:exporter].add_worksheet('Table Data') do |sheet|
          # Add metadata section
          sheet.add_section('Table Information', metadata)

          # Add table data with headers
          header_row_index = sheet.add_header(table_headers)

          # Add data rows with hyperlink support
          table_rows.each do |row_data|
            # Process row data to handle hyperlinks
            processed_row = row_data.map do |cell_value|
              cell_value.is_a?(Hash) && cell_value[:hyperlink] ? cell_value[:text] : cell_value
            end

            # Add the row
            row_index = sheet.add_row(processed_row)

            # Add hyperlinks to cells that need them
            row_data.each_with_index do |cell_value, col_index|
              next unless cell_value.is_a?(Hash) && cell_value[:hyperlink]

              sheet.add_hyperlink(row_index, col_index, cell_value[:hyperlink])
            end
          end

          # Auto-fit columns and freeze panes
          sheet.auto_fit_columns
          sheet.freeze_panes(header_row_index + 1, 0) if table_headers.any?
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      # Set XLSX response headers with proper encoding
      def configure_xlsx_response(exporter)
        env['api.format'] = :binary
        content_type 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'

        # Use both filename and filename* for better browser compatibility
        filename = exporter.filename
        encoded_filename = URI.encode_www_form_component(filename)
        header('Content-Disposition', "attachment; filename=\"#{filename}\"; filename*=UTF-8''#{encoded_filename}")
      end
    end
    # rubocop:enable Metrics/BlockLength
  end
end
