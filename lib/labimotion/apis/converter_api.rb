# frozen_string_literal: true

module Labimotion
  class ConverterAPI < Grape::API
    helpers Labimotion::DatasetHelpers
    helpers do
      def load_converter_config!
        @conf = Rails.configuration.converter&.url
        @profile = Rails.configuration.converter&.profile
        error!(406) unless @conf && @profile
      end

      def require_converter_admin!
        error!(401) unless current_user.profile&.data&.fetch('converter_admin', false)
      end

      def uploaded_file
        params[:file].is_a?(Array) ? params[:file][0] : params[:file]
      end
    end

    resource :converter do
      resource :datasets do
        desc 'list Generic Dataset Klass'
        get do
          list = klass_list(true, false)
          list.map do |kl|
            pr = kl.properties_release
            pr['name'] = kl.label
            pr['ols'] = kl.ols_term_id
            pr
          end || []
        end
      end

      resource :datasets_units do
        desc 'list Generic Dataset Klass'
        get do
          Labimotion::Units::FIELDS
        end
      end

      resource :profiles do

        before do
          load_converter_config!
        end

        desc 'Fetch profiles (no admin required)'
        get do
          profiles = Labimotion::Converter.fetch_profiles
          { profiles: profiles, client: @profile }
        end

        desc 'Create profile'
        post do
          require_converter_admin!
          Labimotion::Converter.create_profile(params)
        end

        route_param :id do
          desc 'Update profile'
          put do
            require_converter_admin!
            Labimotion::Converter.update_profile(params)
          end

          desc 'Delete profile'
          delete do
            require_converter_admin!
            Labimotion::Converter.delete_profile(params[:id])
          end
        end

        resource :restore do
          route_param :profile_id,
                      requirements: {
                        profile_id: /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/
                      } do

            route_param :profile_version,
                        requirements: {
                          profile_version: /\d+\.\d+/
                        } do
              get do
                {test_version: params[:profile_id], version: params[:profile_version]}
              end
              desc 'Restore profile'
              post do
                require_converter_admin!

                Labimotion::Converter.restore(
                  params[:profile_id],
                  params[:profile_version],
                  params[:hard]
                )
              end
            end
          end
        end
      end
      resource :structure do
        helpers do
          def convert_structure(molfile)
            molecule_viewer = Matrice.molecule_viewer
            if molecule_viewer.blank? || molecule_viewer[:chembox].blank?
              { molfile: molfile }
            else
              options = { timeout: 10, body: { mol: molfile }.to_json, headers: { 'Content-Type' => 'application/json' } }
              response = HTTParty.post("#{molecule_viewer[:chembox]}/core/rdkit/v1/structure", options)
              if response.code == 200
                { molfile: (response.parsed_response && response.parsed_response['molfile']) || molfile }
              else
                { molfile: molfile }
              end
            end
          end
        end
        desc 'convert molfile to 3d'
        params do
          requires :mol, type: String, desc: 'Molecule molfile'
        end
        post do
          convert_structure(params[:mol])
        rescue StandardError => e
          # return { msg: { level: 'error', message: e } }
          { molfile: params[:mol], msg: { level: 'error', message: e } }
        end
      end

      resource :options do
        before do
          load_converter_config!
          require_converter_admin!
        end
        desc 'fetch options'
        get do
          options = Labimotion::Converter.fetch_options
          { options: options, client: @profile }
        end
      end

      resource :tables do
        before do
          load_converter_config!
          require_converter_admin!
        end
        desc 'create tables'
        post do
          file = uploaded_file
          res = Labimotion::Converter.create_tables(file['tempfile']) unless file.nil?
          res['metadata']['file_name'] = file['filename']
          res
        end
      end

      resource :conversions do
        before do
          load_converter_config!
          require_converter_admin!
        end
        desc 'convert file'
        post do
          file = uploaded_file
          res = Labimotion::Converter.test_conversions(file['tempfile'], params[:format]) unless file.nil?
          res
        end
      end

    end
  end
end

