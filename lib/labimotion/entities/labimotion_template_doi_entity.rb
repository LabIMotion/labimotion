# frozen_string_literal: true

module Labimotion
  # Serializes the DOI + publication state for a LabIMotion template
  # (ElementKlass / SegmentKlass / DatasetKlass). Built ad-hoc by
  # Labimotion::LabimotionDoiAPI; not a direct AR record entity.
  class LabimotionTemplateDoiEntity < Grape::Entity
    expose :type
    expose :klass_id
    expose :doi do |obj|
      next nil unless obj[:doi]

      {
        id: obj[:doi].id,
        suffix: obj[:doi].suffix,
        full_doi: obj[:doi].full_doi,
        version: ::Doi.labimotion_doi_version(obj[:doi]),
        minted: obj[:doi].minted == true,
        minted_at: obj[:doi].minted_at
      }
    end
    expose :released_doi_version
    expose :publication
    expose :released_at
    expose :released_by
    expose :new_version_available
    expose :next_doi_version
    expose :template_url
  end
end
