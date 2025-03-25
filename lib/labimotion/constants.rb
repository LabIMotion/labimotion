# frozen_string_literal: true

module Labimotion
  module Constants
    module DateTime
      DATE_FORMAT = '%Y-%m-%d'
      DATETIME_FORMAT = '%Y-%m-%d %H:%M:%S %Z'
      TIME_FORMAT = '%H:%M:%S %Z'
      TIME_ZONE = 'UTC'
    end

    module File
      ENCODING = 'UTF-8'
    end

    module CHMO
      CV = 'Cyclic Voltammetry'
    end

    module Mapper
      NMR_CONFIG = ::File.join(__dir__, 'libs', 'data', 'mapper', 'Source.json').freeze
      WIKI_CONFIG = ::File.join(__dir__, 'libs', 'data', 'mapper', 'Chemwiki.json').freeze
    end

    module Klass
      ELEMENT = 'ElementKlass'
      SEGMENT = 'SegmentKlass'
      DATASET = 'DatasetKlass'
      ALL = [ELEMENT, SEGMENT, DATASET].freeze
    end
  end
end
