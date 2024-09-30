# frozen_string_literal: true
require 'labimotion/models/concerns/generic_revisions'
require 'labimotion/models/concerns/segmentable'
require 'labimotion/models/concerns/workflow'
require 'labimotion/models/concerns/linked_properties'

module Labimotion
  class Element < ApplicationRecord
    acts_as_paranoid
    self.table_name = :elements
    include PgSearch::Model
    include ElementUIStateScopes
    include Collectable
    include Taggable
    include Workflow
    include Segmentable
    include GenericRevisions
    include LinkedProperties

    multisearchable against: %i[name short_label]

    pg_search_scope :search_by_substring, against: %i[name short_label], using: { trigram: { threshold: 0.0001 } }

    attr_accessor :can_copy

    scope :by_name, ->(query) { where('name ILIKE ?', "%#{sanitize_sql_like(query)}%") }
    scope :by_short_label, ->(query) { where('short_label ILIKE ?', "%#{sanitize_sql_like(query)}%") }
    scope :by_klass_id_short_label, ->(klass_id, short_label) { where('element_klass_id = ? and short_label ILIKE ?', klass_id, "%#{sanitize_sql_like(short_label)}%") }
    scope :by_sample_ids, ->(ids) { joins(:elements_samples).where('sample_id IN (?)', ids) }
    scope :by_klass_id, ->(klass_id) { where('element_klass_id = ? ', klass_id) }

    belongs_to :element_klass, class_name: 'Labimotion::ElementKlass'

    has_ancestry orphan_strategy: :adopt

    has_many :collections_elements,  inverse_of: :element, dependent: :destroy, class_name: 'Labimotion::CollectionsElement'
    has_many :collections, through: :collections_elements
    has_many :attachments, as: :attachable
    has_many :elements_samples, dependent: :destroy, class_name: 'Labimotion::ElementsSample'
    has_many :samples, through: :elements_samples, source: :sample
    has_one :container, :as => :containable
    has_many :elements_revisions, dependent: :destroy, class_name: 'Labimotion::ElementsRevision'

    accepts_nested_attributes_for :collections_elements

    scope :elements_created_time_from, ->(time) { where('elements.created_at >= ?', time) }
    scope :elements_created_time_to, ->(time) { where('elements.created_at <= ?', time) }
    scope :elements_updated_time_from, ->(time) { where('elements.updated_at >= ?', time) }
    scope :elements_updated_time_to, ->(time) { where('elements.updated_at <= ?', time) }

    belongs_to :creator, foreign_key: :created_by, class_name: 'User'
    validates :creator, presence: true

    has_many :elements_elements, foreign_key: :parent_id, class_name: 'Labimotion::ElementsElement'
    has_many :elements, through: :elements_elements, source: :element, class_name: 'Labimotion::Element'

    before_save :auto_set_short_label
    after_create :update_counter
    before_destroy :delete_attachment

    def user_labels
      tag&.taggable_data&.fetch('user_labels', nil)
    end

    def attachments
      Attachment.where(attachable_id: self.id, attachable_type: self.class.name)
    end

    def self.get_associated_samples(element_ids)
      Labimotion::ElementsSample.where(element_id: element_ids).pluck(:sample_id)
    end

    def analyses
      container ? container.analyses : []
    end

    def auto_set_short_label
      return if short_label && !short_label_changed?

      return if parent && (self.short_label = "#{parent.short_label}-#{parent.children.with_deleted.count.to_i.succ}")

      prefix = element_klass.klass_prefix
      if creator.counters[element_klass.name].nil?
        creator.counters[element_klass.name] = '0'
        creator.update_columns(counters: creator.counters)
        creator.reload
      end
      counter = creator.counters[element_klass.name].to_i.succ
      self.short_label = "#{creator.initials}-#{prefix}#{counter}"
    end

    def update_counter
      creator.increment_counter element_klass.name
    end

    def self.get_associated_elements(element_ids)
      pids = Labimotion::Element.where(id: element_ids).pluck :id
      get_ids = proc do |eids|
        eids.each do |p|
          cs = Labimotion::Element.find_by(id: p)&.elements.where.not(id: pids).pluck :id
          next if cs.empty?

          pids = (pids << cs).flatten.uniq
          get_ids.call(cs)
        end
      end
      get_ids.call(pids)
      pids
    end

    def thumb_svg
      image_atts = attachments.select(&:type_image?)
      attachment = image_atts[0] || attachments[0]
      preview = attachment&.read_thumbnail
      (preview && Base64.encode64(preview)) || 'not available'
    end

    def split(user, col_ids)
      subelement = self.dup
      subelement.name = self.name if self.name.present?
      subelement.parent = self
      subelement.properties = detach_properties(properties)
      subelement.created_by = user.id
      collections = (Collection.where(id: col_ids) | Collection.where(user_id: user, label: 'All', is_locked: true))
      subelement.collections << collections
      subelement.container = Container.create_root_container
      subelement.save!
      subelement
    end

    def migrate_workflow
      return if properties.nil? || properties_release.nil?

      return if properties['flow'].nil? && properties_release['flow'].nil?

      update_column(:properties, split_workflow(properties)) if properties['flow']
      update_column(:properties_release, split_workflow(properties_release)) if properties_release['flow']
    end

    private

    def delete_attachment
      if Rails.env.production?
        attachments.each do |attachment|
          attachment.delay(run_at: 96.hours.from_now, queue: 'attachment_deletion').destroy!
        end
      else
        attachments.each(&:destroy!)
      end
    end
  end
end
