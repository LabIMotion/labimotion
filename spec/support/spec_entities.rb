# frozen_string_literal: true

require 'spec_helper'

# Test entities for specs
module SpecEntities
  # Test entity for VocabularyEntity specs
  Vocabulary = Struct.new(:id, :identifier, :name, :label, :field_type, :opid,
                         :term_id, :field_id, :properties, :source, :source_id,
                         :layer_id, keyword_init: true)

  # Test entity for GenericKlassEntity specs
  GenericKlass = Struct.new(:id, :uuid, :label, :desc, :is_active, :version, :place,
                           :released_at, :identifier, :sync_time, :properties_template,
                           :properties_release, :created_at, :updated_at, :displayed_in_list,
                           keyword_init: true)

  # Test entity for DatasetKlassEntity specs (extends GenericKlass with ols_term_id)
  DatasetKlass = Struct.new(:id, :uuid, :label, :desc, :is_active, :version, :place,
                           :released_at, :identifier, :sync_time, :properties_template,
                           :properties_release, :created_at, :updated_at, :displayed_in_list,
                           :ols_term_id, keyword_init: true)

  # Test entity for DatasetEntity specs
  Dataset = Struct.new(:id, :dataset_klass_id, :properties, :properties_release,
                       :element_id, :element_type, :klass_uuid, :dataset_klass,
                       :displayed_in_list, keyword_init: true) do
    # Add the &. safe navigation behavior for dataset_klass
    def dataset_klass
      self[:dataset_klass]
    end
  end

  # Helper method to create GenericKlass with default displayed_in_list: true
  def self.default_generic_klass(**attributes)
    GenericKlass.new(attributes.merge(displayed_in_list: true))
  end

  # Helper method to create GenericKlass without displayed_in_list (simulating default behavior)
  def self.minimal_generic_klass(**attributes)
    GenericKlass.new(attributes.except(:displayed_in_list))
  end

  # Helper method to create DatasetKlass with default displayed_in_list: true
  def self.default_dataset_klass(**attributes)
    DatasetKlass.new(attributes.merge(displayed_in_list: true))
  end

  # Helper method to create Dataset with associated DatasetKlass
  def self.dataset_with_klass(**attributes)
    klass_attrs = attributes.delete(:dataset_klass_attrs) || {}
    dataset_klass = DatasetKlass.new(klass_attrs)
    Dataset.new(attributes.merge(dataset_klass: dataset_klass))
  end
end

# Mock DateTime#present? if not available (this is safer as it's just a method addition)
class DateTime
  def present?
    !nil?
  end unless method_defined?(:present?)
end
