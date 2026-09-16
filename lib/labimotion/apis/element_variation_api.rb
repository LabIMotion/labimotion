# frozen_string_literal: true

require 'uri'

module Labimotion
  class ElementVariationAPI < Grape::API
    XLSX_CONTENT_TYPE = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'

    rescue_from ActiveRecord::RecordNotFound do
      error!('404 Element not found', 404)
    end

    helpers do
      def configure_xlsx_response(filename)
        env['api.format'] = :binary
        content_type XLSX_CONTENT_TYPE
        encoded = URI.encode_www_form_component(filename)
        header('Content-Disposition', "attachment; filename=\"#{filename}\"; filename*=UTF-8''#{encoded}")
      end

      def uploaded_xlsx_path!(file)
        filename = file[:filename].to_s
        error!('400 Bad Request - expected an .xlsx file', 400) unless filename.downcase.end_with?('.xlsx')

        tempfile = file[:tempfile]
        error!('400 Bad Request - upload is empty', 400) if tempfile.nil?

        tempfile.path
      end
    end

    resource :element_variations do
      params do
        requires :element_id, type: Integer, desc: 'Generic element id'
      end
      # rubocop:disable Metrics/BlockLength
      route_param :element_id do
        before do
          @element = Labimotion::Element.find(params[:element_id])
          error!('401 Unauthorized', 401) unless ElementPolicy.new(current_user, @element).read?
        end

        desc 'Return element variations for a generic element'
        get do
          record = Labimotion::ElementVariation.find_or_initialize_by(element_id: @element.id)
          present record, with: Labimotion::ElementVariationEntity, root: 'element_variation'
        end

        desc 'Upsert element variations for a generic element'
        params do
          requires :variations, type: Hash, desc: 'Variations keyed by row uuid'
          optional :layout, type: Hash, desc: 'Column layout (selected/order/units/rowOrder)'
        end
        put do
          error!('401 Unauthorized', 401) unless ElementPolicy.new(current_user, @element).update?

          record = Labimotion::ElementVariation.find_or_initialize_by(element_id: @element.id)
          record.variations = params[:variations] || {}
          record.layout = params[:layout] || {} if params.key?(:layout) && record.class.column_names.include?('layout')
          record.save!

          present record, with: Labimotion::ElementVariationEntity, root: 'element_variation'
        end

        desc 'Export element variations as an xlsx workbook'
        get :export do
          exporter = Labimotion::ExportElementVariations.new(@element, user: current_user)
          configure_xlsx_response(exporter.filename)
          exporter.read
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          error!("500 Internal Server Error: #{e.message}", 500)
        end

        desc 'Import element variations from an xlsx workbook produced by the export'
        params do
          requires :file, type: File, desc: 'xlsx file'
        end
        post :import do
          error!('401 Unauthorized', 401) unless ElementPolicy.new(current_user, @element).update?

          path = uploaded_xlsx_path!(params[:file])
          importer = Labimotion::ImportElementVariations.new(@element, path)
          record = importer.execute!

          {
            element_variation: Labimotion::ElementVariationEntity.represent(record),
            warnings: importer.warnings
          }
        rescue Labimotion::ImportElementVariations::InvalidWorkbook => e
          error!(e.message, 422)
        rescue StandardError => e
          Labimotion.log_exception(e, current_user)
          error!("500 Internal Server Error: #{e.message}", 500)
        end
      end
      # rubocop:enable Metrics/BlockLength
    end
  end
end
