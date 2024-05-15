module Labimotion
  ## Properties Field Type
  class FieldType
    CHECKBOX = 'checkbox'.freeze
    DATE = 'date'.freeze
    DATETIME = 'datetime'.freeze
    DATETIME_RANGE = 'datetime-range'.freeze
    SELECT = 'select'.freeze
    INTEGER = 'integer'.freeze
    INPUT_GROUP = 'input-group'.freeze
    WF_NEXT = 'wf-next'.freeze
    TEXT_FORMULA = 'text-formula'.freeze
    SYSTEM_DEFINED = 'system-defined'.freeze
    SYS_REACTION = 'sys-reaction'.freeze
    DRAG = 'drag'.freeze
    DRAG_ELEMENT = 'drag_element'.freeze
    DRAG_MOLECULE = 'drag_molecule'.freeze
    DRAG_SAMPLE = 'drag_sample'.freeze
    DRAG_REACTION = 'drag_reaction'.freeze
    DRAG_MS = [DRAG_MOLECULE, DRAG_SAMPLE].freeze
    DRAG_ALL = [DRAG_ELEMENT, DRAG_MOLECULE, DRAG_SAMPLE, DRAG_REACTION, SYS_REACTION].freeze
    TABLE = 'table'.freeze
    UPLOAD = 'upload'.freeze
    TEXT = 'text'.freeze
    TEXTAREA = 'textarea'.freeze
  end
end
