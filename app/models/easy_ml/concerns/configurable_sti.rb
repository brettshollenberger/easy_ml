module EasyML
  module Concerns
    module ConfigurableSTI
      extend ActiveSupport::Concern

      included do
        self.filter_attributes += [:configuration]
        class_attribute :type_map, instance_writer: false
        class_attribute :parent_module, instance_writer: false
        class_attribute :sti_column_name, instance_writer: false
        class_attribute :configuration_attributes, instance_writer: false, default: []

        after_initialize :read_from_configuration
        before_save :store_in_configuration
      end

      class_methods do
        def sti_type_column(column_name)
          self.inheritance_column = column_name
          self.sti_column_name = column_name

          define_method("#{column_name}=") do |value|
            write_sti_type(value)
          end
        end

        def sti_module(module_name)
          self.parent_module = module_name
        end

        def register_sti_types(mapping)
          self.type_map = mapping.freeze
        end

        def find_sti_class(type_name)
          return get_sti_class(type_name) if type_name.in?(type_map.values)

          type_key = type_name.to_s.underscore.to_sym
          normalized_type = type_map[type_key] || type_name

          get_sti_class(normalized_type)
        end

        def get_sti_class(type_name)
          type_name = type_name.to_s
          if get_parent_module.constants.include?(type_name.to_sym)
            get_parent_module.const_get(type_name)
          else
            type_name.constantize
          end
        end

        def get_parent_module
          parent_module&.constantize || module_parent_name.constantize
        end

        def sti_name
          name.demodulize
        end

        def add_configuration_attributes(*attrs)
          self.configuration_attributes += attrs
        end

        def new(*args, &block)
          attributes = args.first.is_a?(Hash) ? args.first : {}
          unless attributes[sti_column_name] || attributes[sti_column_name.to_s]
            # Set default sti_column_name if not provided
            default_type = default_sti_type || sti_name
            attributes = attributes.merge(sti_column_name => default_type)
            args[0] = attributes
          end

          type_value = attributes[sti_column_name] || attributes[sti_column_name.to_s]
          klass = find_sti_class(type_value)
          return klass.new(*args, &block) if klass != self

          super(*args, &block)
        end

        # Helper method to set the default STI type
        def default_sti_type(value = nil)
          if value
            @default_sti_type = value
          else
            @default_sti_type || sti_name
          end
        end
      end

      private

      def write_sti_type(value)
        @type_value = value
        normalize_type
        write_attribute(self.class.sti_column_name, @type_value)
      end

      def normalize_type
        return if @type_value.nil?
        return if @type_value.in?(self.class.type_map.values)

        type_key = @type_value.to_sym if @type_value.respond_to?(:to_sym)
        @type_value = self.class.type_map[type_key] if self.class.type_map.key?(type_key)
      end

      def store_in_configuration
        self.class.configuration_attributes.each do |attr|
          value = instance_variable_get("@#{attr}") || try(attr)
          next if value.nil?

          self.configuration = (configuration || {}).merge(attr.to_s => value)
        end
      end

      def read_from_configuration
        return unless configuration

        self.class.configuration_attributes.each do |attr|
          next unless configuration.key?(attr.to_s)

          instance_variable_set("@#{attr}", configuration[attr.to_s])
        end
      end
    end
  end
end
