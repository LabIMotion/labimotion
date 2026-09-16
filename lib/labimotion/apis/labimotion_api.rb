# frozen_string_literal: true

# app/api/labimotion/central_api.rb
module Labimotion
  class LabimotionAPI < Grape::API
    mount Labimotion::ConverterAPI
    mount Labimotion::ExporterAPI
    mount Labimotion::GenericKlassAPI
    mount Labimotion::GenericElementAPI
    mount Labimotion::GenericDatasetAPI
    mount Labimotion::SegmentAPI
    mount Labimotion::LabimotionHubAPI
    mount Labimotion::StandardLayerAPI
    mount Labimotion::VocabularyAPI
    mount Labimotion::UserAPI
    mount Labimotion::MttAPI
    mount Labimotion::ElementVariationAPI
    mount Labimotion::LabimotionDoiAPI
    mount Labimotion::LabimotionTemplateBrowseAPI
    mount Labimotion::WellplateAPI
  end
end
