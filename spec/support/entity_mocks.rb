# frozen_string_literal: true

# Shared Entity mock setup for all entity tests
# This prevents duplication and conflicts between test files

module EntityMocks
  def self.setup!
    # Only set up mocks once to avoid conflicts
    return if @mocks_setup

    # Create a mock Entity module that only exists during tests
    entity_module = Module.new

    application_entity_class = Class.new do
      @@formatters = {}

      def self.format_with(name, &block)
        @@formatters[name] = block
      end

      def self.expose(*attrs, **options, &block)
        attrs.each do |attr|
          define_method(attr) do |obj = nil|
            target_obj = obj || @object

            # Handle the 'unless' condition
            if options[:unless]
              condition_field = options[:unless]
              condition_value = target_obj.respond_to?(condition_field) ? target_obj.send(condition_field) : nil

              condition_value = true if condition_field == :displayed_in_list && condition_value.nil?

              # If the unless condition is truthy, don't expose (return nil)
              return nil if condition_value
            end

            # Normal exposure logic
            if block_given?
              instance_exec(target_obj, &block)
            else
              value = target_obj.respond_to?(attr) ? target_obj.send(attr) : nil
              if options[:format_with] && @@formatters[options[:format_with]]
                @@formatters[options[:format_with]].call(value)
              else
                value
              end
            end
          end
        end
      end

      def self.expose_timestamps(options = {})
        timestamp_fields = options[:timestamp_fields] || []
        timestamp_fields.each do |field|
          define_method(field) do |obj = nil|
            target_obj = obj || @object
            value = target_obj.respond_to?(field) ? target_obj.send(field) : nil

            if value && @@formatters[:eln_timestamp]
              @@formatters[:eln_timestamp].call(value)
            else
              value
            end
          end
        end
      end

      def initialize(object)
        @object = object
      end

      # Provide the object method like Grape::Entity does
      def object
        @object
      end
    end

    # Create PropertiesEntity mock (DatasetEntity inherits from this)
    properties_entity_class = Class.new(application_entity_class) do
      # PropertiesEntity-specific functionality can be added here if needed
    end

    # Set up Entities::ApplicationEntity for inheritance (note plural "Entities")
    entities_application_entity_class = Class.new(application_entity_class)

    entity_module.const_set('ApplicationEntity', entities_application_entity_class)
    entity_module.const_set('PropertiesEntity', properties_entity_class)

    # Remove existing Entities constant if it exists, then set our mock
    Object.send(:remove_const, 'Entities') if defined?(Entities)
    Object.const_set('Entities', entity_module)

    # Set up Labimotion module structure
    unless defined?(Labimotion)
      labimotion_module = Module.new
      Object.const_set('Labimotion', labimotion_module)
    end

    @mocks_setup = true
  end

  def self.load_entities!
    # Set up Labimotion::Prop constants that VocabularyEntity needs
    unless defined?(Labimotion::Prop)
      prop_module = Module.new
      prop_module.const_set('ELEMENT', 'element')
      prop_module.const_set('SEGMENT', 'segment')
      prop_module.const_set('DATASET', 'dataset')
      Labimotion.const_set('Prop', prop_module)
    end

    # Set up the Labimotion::ApplicationEntity class before loading entities
    unless defined?(Labimotion::ApplicationEntity)
      labimotion_application_entity = Class.new(Entities::ApplicationEntity)

      labimotion_application_entity.format_with(:eln_timestamp) do |datetime|
        datetime.present? ? datetime.strftime('%Y-%m-%d %H:%M:%S %Z') : nil
      end

      Labimotion.const_set('ApplicationEntity', labimotion_application_entity)
    end

    # Now load the entity files - dependencies are already set up
    unless defined?(Labimotion::DatasetKlassEntity)
      require_relative '../../lib/labimotion/entities/dataset_klass_entity'
    end
    unless defined?(Labimotion::DatasetEntity)
      require_relative '../../lib/labimotion/entities/dataset_entity'
    end
    unless defined?(Labimotion::VocabularyEntity)
      require_relative '../../lib/labimotion/entities/vocabulary_entity'
    end
    unless defined?(Labimotion::GenericKlassEntity)
      require_relative '../../lib/labimotion/entities/generic_klass_entity'
    end
  end

  def self.reset!
    @mocks_setup = false
  end
end
