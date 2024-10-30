module EasyML
  module Concerns
    module ConfigurableAdapter
      extend ActiveSupport::Concern

      class ComponentError < StandardError; end
      class InvalidComponentType < ComponentError; end
      class MissingRequiredConfig < ComponentError; end

      class_methods do
        def configurable_adapter(name, options: {})
          # Define the component registry
          class_attribute :_component_registry
          self._component_registry ||= {}

          # Store options for this component
          self._component_registry[name] = options

          # Define the getter method
          define_method(name) do
            config = read_attribute(name)
            return nil unless config

            config = config.symbolize_keys
            default_key = "#{name}_type".to_sym
            fallback_key = "type"
            config_key = config.key?(default_key) ? default_key : fallback_key
            type = config.delete(config_key)

            registry = self.class._component_registry[name]
            klass = registry&.[](type&.to_sym)

            unless klass
              valid_types = registry&.keys&.join(", ")
              raise InvalidComponentType, "Invalid #{name} type '#{type}'. Valid types are: #{valid_types}"
            end

            # Validate required config based on implementation
            if klass.respond_to?(:required_config)
              missing = klass.required_config - config.keys
              unless missing.empty?
                raise MissingRequiredConfig, "Missing required config for #{name}: #{missing.join(", ")}"
              end
            end

            # Instantiate the component
            klass.new(config)
          end
        end
      end
    end
  end
end
