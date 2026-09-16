# frozen_string_literal: true

module Labimotion
  # Shared helpers for LabIMotion template DOIs: the type <-> klass mapping,
  # authorization, the public Template Hub URL and "is a new version reservable"
  # check. Used by the template DOI usecases and APIs.
  module TemplateDoiHelpers
    KLASS_BY_TYPE = {
      'element' => ::Labimotion::ElementKlass,
      'segment' => ::Labimotion::SegmentKlass,
      'dataset' => ::Labimotion::DatasetKlass
    }.freeze

    # Maps a template record to the `generic_admin` profile key that grants
    # admin rights over it. Keys are plural, matching the LabIMotion gem's
    # `authenticate_admin!` and `User#generic_admin`.
    GENERIC_ADMIN_KEY = {
      ::Labimotion::ElementKlass => 'elements',
      ::Labimotion::SegmentKlass => 'segments',
      ::Labimotion::DatasetKlass => 'datasets'
    }.freeze

    module_function

    # True once the template's latest DOI has been released (minted) and the
    # template has since moved to a new major version — i.e. a DOI for the new
    # version may now be reserved. False while there is no DOI, the latest is
    # still unreleased, or the DOI version is unchanged (released = read-only,
    # and minor template revisions keep the same DOI).
    def new_version_available?(record)
      latest = ::Doi.labimotion_latest_doi(record)
      return false unless latest&.minted

      ::Doi.labimotion_doi_version(latest) != ::Doi.labimotion_version_segment(record)
    end

    def klass_type_for(record)
      case record
      when ::Labimotion::ElementKlass then 'element'
      when ::Labimotion::SegmentKlass then 'segment'
      when ::Labimotion::DatasetKlass then 'dataset'
      end
    end

    # Public URL that opens the template in the LabIMotion Template Hub's
    # "Find a Template" page (the Finder), preselecting the template type, the
    # template and its release version:
    #   /home/genericHub?type=finder&kind=<type>&id=<identifier|uuid>&version=<v>
    # Used as the DOI's DataCite landing page and surfaced in the UI.
    def template_url(record)
      type = klass_type_for(record)
      host = ENV['REPO_HOST'].presence || ENV['DOI_DOMAIN_TEST'].presence ||
             ENV['DOI_DOMAIN'].presence || 'https://www.chemotion-repository.net'
      record_id = record.try(:identifier).presence || record.try(:uuid).presence || record.id
      query = "type=finder&kind=#{type}&id=#{record_id}"
      version = record.try(:version)
      query += "&version=#{version}" if version.present?
      "#{host.chomp('/')}/home/genericHub?#{query}"
    end

    # A user may manage a template's DOI iff they hold the LabIMotion
    # `generic_admin` right for that template kind — the same gate the gem's
    # `authenticate_admin!` and the admin UI use. `admin_ids`/`created_by` do
    # NOT apply: segment templates carry neither, so they were always denied.
    def authorized?(record, user)
      return false unless record && user

      key = GENERIC_ADMIN_KEY[record.class]
      return false unless key

      admin = user.respond_to?(:generic_admin) ? user.generic_admin : nil
      admin.is_a?(Hash) && !!admin[key]
    end
  end
end
