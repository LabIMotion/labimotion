# frozen_string_literal: true
require 'grape'
require 'labimotion/utils/utils'
# Helper for associated sample
module Labimotion
  ## Generic Helpers
  module ParamHelpers
    extend Grape::API::Helpers
       ## Element Klass Params
      params :upload_element_klass_params do
        requires :name, type: String, desc: 'Klass Name'
        optional :label, type: String, desc: 'Klass label'
        optional :desc, type: String, desc: 'Klass desc'
        optional :klass_prefix, type: String, desc: 'Klass klass_prefix'
        optional :icon_name, type: String, desc: 'Klass icon_name'
        requires :properties_template, type: Hash, desc: 'Klass template'
        optional :properties_release, type: Hash, desc: 'Klass release'
        optional :released_at, type: DateTime, desc: 'Klass released_at'
        requires :uuid, type: String, desc: 'Klass uuid'
        requires :place, type: Integer, desc: 'Klass place'
        requires :identifier, type: String, desc: 'Klass identifier'
        optional :sync_time, type: DateTime, desc: 'Klass sync_time'
        optional :version, type: String, desc: 'Klass version'
      end
      
      params :create_element_klass_params do
        requires :name, type: String, desc: 'Element Klass Name'
        requires :label, type: String, desc: 'Element Klass Label'
        requires :klass_prefix, type: String, desc: 'Element Klass Short Label Prefix'
        optional :icon_name, type: String, desc: 'Element Klass Icon Name'
        optional :desc, type: String, desc: 'Element Klass Desc'
        optional :properties_template, type: Hash, desc: 'Element Klass properties template'
      end

      params :update_element_klass_params do
        requires :id, type: Integer, desc: 'Element Klass ID'
        optional :label, type: String, desc: 'Element Klass Label'
        optional :klass_prefix, type: String, desc: 'Element Klass Short Label Prefix'
        optional :icon_name, type: String, desc: 'Element Klass Icon Name'
        optional :desc, type: String, desc: 'Element Klass Desc'
        optional :place, type: String, desc: 'Element Klass Place'
      end
      
      ## Element Params
      params :create_element_params do
        requires :element_klass, type: Hash
        requires :name, type: String
        optional :properties, type: Hash
        optional :properties_release, type: Hash
        optional :collection_id, type: Integer
        requires :container, type: Hash
        optional :segments, type: Array, desc: 'Segments'
      end
      
      params :update_element_params do
        requires :id, type: Integer, desc: 'element id'
        optional :name, type: String
        requires :properties, type: Hash
        optional :properties_release, type: Hash
        requires :container, type: Hash
        optional :segments, type: Array, desc: 'Segments'
      end
      
      ## Segment Klass Params
      params :upload_segment_klass_params do
        requires :label, type: String, desc: 'Klass label'
        optional :desc, type: String, desc: 'Klass desc'
        requires :properties_template, type: Hash, desc: 'Klass template'
        optional :properties_release, type: Hash, desc: 'Klass release'
        optional :released_at, type: DateTime, desc: 'Klass released_at'
        requires :uuid, type: String, desc: 'Klass uuid'
        requires :place, type: Integer, desc: 'Klass place'
        requires :identifier, type: String, desc: 'Klass identifier'
        optional :sync_time, type: DateTime, desc: 'Klass sync_time'
        optional :version, type: String, desc: 'Klass version'
        requires :element_klass, type: Hash do
          use :upload_element_klass_params
        end
      end

      params :update_segment_klass_params do
        requires :id, type: Integer, desc: 'Segment Klass ID'
        optional :label, type: String, desc: 'Segment Klass Label'
        optional :desc, type: String, desc: 'Segment Klass Desc'
        optional :place, type: String, desc: 'Segment Klass Place', default: '100'
        optional :identifier, type: String, desc: 'Segment Identifier'
      end

      params :create_segment_klass_params do
        requires :label, type: String, desc: 'Segment Klass Label'
        requires :element_klass, type: Integer, desc: 'Element Klass Id'
        optional :desc, type: String, desc: 'Segment Klass Desc'
        optional :place, type: String, desc: 'Segment Klass Place', default: '100'
        optional :properties_template, type: Hash, desc: 'Element Klass properties template'
      end
  end
end