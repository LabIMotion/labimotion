# app/api/labimotion/central_api.rb
module Labimotion
  class LabimotionAPI < Grape::API
    mount Labimotion::ConverterAPI
    mount Labimotion::GenericKlassAPI
    mount Labimotion::GenericElementAPI
    mount Labimotion::GenericDatasetAPI
    mount Labimotion::SegmentAPI
    mount Labimotion::LabimotionHubAPI
    mount Labimotion::StandardLayerAPI
    mount Labimotion::VocabularyAPI
  end
end