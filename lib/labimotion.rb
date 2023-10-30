# In your_gem_name.rb or main Ruby file
module Labimotion

  autoload :VERSION, 'labimotion/version'

  def self.logger
    @@labimotion_logger ||= Logger.new(Rails.root.join('log/labimotion.log')) # rubocop:disable Style/ClassVars
  end

  def self.log_exception(exception, current_user = nil)
    Labimotion.logger.error("version: #{Labimotion::VERSION}; #{Labimotion::IS_RAILS5}, (#{current_user&.id}) \n Exception: #{exception.message}")
    Labimotion.logger.error(exception.backtrace.join("\n"))
  end

  autoload :Utils, 'labimotion/utils/utils'

  ######## APIs
  autoload :GenericElementAPI, 'labimotion/apis/generic_element_api'
  autoload :GenericDatasetAPI, 'labimotion/apis/generic_dataset_api'
  autoload :SegmentAPI, 'labimotion/apis/segment_api'
  autoload :LabimotionHubAPI, 'labimotion/apis/labimotion_hub_api'
  autoload :ConverterAPI, 'labimotion/apis/converter_api'

  ######## Entities
  autoload :ElementEntity, 'labimotion/entities/element_entity'
  autoload :ElnElementEntity, 'labimotion/entities/eln_element_entity'

  autoload :SegmentEntity, 'labimotion/entities/segment_entity'
  autoload :DatasetEntity, 'labimotion/entities/dataset_entity'

  autoload :GenericKlassEntity, 'labimotion/entities/generic_klass_entity'
  autoload :ElementKlassEntity, 'labimotion/entities/element_klass_entity'
  autoload :SegmentKlassEntity, 'labimotion/entities/segment_klass_entity'
  autoload :DatasetKlassEntity, 'labimotion/entities/dataset_klass_entity'

  autoload :GenericEntity, 'labimotion/entities/generic_entity'
  autoload :GenericPublicEntity, 'labimotion/entities/generic_public_entity'
  autoload :KlassRevisionEntity, 'labimotion/entities/klass_revision_entity'
  autoload :ElementRevisionEntity, 'labimotion/entities/element_revision_entity'
  autoload :SegmentRevisionEntity, 'labimotion/entities/segment_revision_entity'
  ## autoload :DatasetRevisionEntity, 'labimotion/entities/dataset_revision_entity'

  ######## Helpers
  autoload :GenericHelpers, 'labimotion/helpers/generic_helpers'
  autoload :ElementHelpers, 'labimotion/helpers/element_helpers'
  autoload :SegmentHelpers, 'labimotion/helpers/segment_helpers'
  autoload :DatasetHelpers, 'labimotion/helpers/dataset_helpers'
  autoload :SearchHelpers, 'labimotion/helpers/search_helpers'
  autoload :ConverterHelpers, 'labimotion/helpers/converter_helpers'
  autoload :SampleAssociationHelpers, 'labimotion/helpers/sample_association_helpers'
  autoload :RepositoryHelpers, 'labimotion/helpers/repository_helpers'

  ######## Libs
  autoload :Converter, 'labimotion/libs/converter'
  autoload :NmrMapper, 'labimotion/libs/nmr_mapper'
  autoload :NmrMapperRepo, 'labimotion/libs/nmr_mapper_repo' ## for Chemotion Repository
  autoload :TemplateHub, 'labimotion/libs/template_hub'
  autoload :ExportDataset, 'labimotion/libs/export_dataset'

  ######## Utils
  autoload :ConState, 'labimotion/utils/con_state'
  autoload :Serializer, 'labimotion/utils/serializer'
  autoload :Search, 'labimotion/utils/search'


  ######## Collection
  autoload :Export, 'labimotion/collection/export'
  autoload :Import, 'labimotion/collection/import'

  ######## Models
  autoload :Element, 'labimotion/models/element'
  autoload :Segment, 'labimotion/models/segment'
  autoload :Dataset, 'labimotion/models/dataset'

  autoload :ElementKlass, 'labimotion/models/element_klass'
  autoload :SegmentKlass, 'labimotion/models/segment_klass'
  autoload :DatasetKlass, 'labimotion/models/dataset_klass'

  autoload :ElementsRevision, 'labimotion/models/elements_revision'
  autoload :SegmentsRevision, 'labimotion/models/segments_revision'
  autoload :DatasetsRevision, 'labimotion/models/datasets_revision'

  autoload :ElementKlassesRevision, 'labimotion/models/element_klasses_revision'
  autoload :SegmentKlassesRevision, 'labimotion/models/segment_klasses_revision'
  autoload :DatasetKlassesRevision, 'labimotion/models/dataset_klasses_revision'

  autoload :ElementsSample, 'labimotion/models/elements_sample'
  autoload :ElementsElement, 'labimotion/models/elements_element'
  autoload :CollectionsElement, 'labimotion/models/collections_element'

  ######## Models/Concerns
  autoload :GenericKlassRevisions, 'labimotion/models/concerns/generic_klass_revisions'
  autoload :GenericRevisions, 'labimotion/models/concerns/generic_revisions'
  autoload :Segmentable, 'labimotion/models/concerns/segmentable'
  autoload :Datasetable, 'labimotion/models/concerns/datasetable'
  autoload :AttachmentConverter, 'labimotion/models/concerns/attachment_converter.rb'


end
