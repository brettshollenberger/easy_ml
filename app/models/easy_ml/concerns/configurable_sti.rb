module EasyML
  module ConfigurableSTI
    extend ActiveSupport::Concern

    included do
      self.filter_attributes += [:configuration]
      class_attribute :type_map, instance_writer: false
      class_attribute :sti_column_name, instance_writer: false
    end

    class_methods do
      def type_column(column_name)
        self.inheritance_column = column_name
        self.sti_column_name = column_name

        # Dynamically define the setter method
        define_method("#{column_name}=") do |value|
          write_sti_type(value)
        end
      end

      def register_types(mapping)
        self.type_map = mapping.freeze
      end

      def find_sti_class(type_name)
        # If it's already a valid STI type, use it directly
        return "#{module_parent_name}::#{type_name}".constantize if type_name.in?(type_map.values)

        # Convert to symbol for lookup
        type_key = type_name.to_s.underscore.to_sym

        # Use the mapped class name if it exists, otherwise use the original
        normalized_type = type_map[type_key] || type_name

        "#{module_parent_name}::#{normalized_type}".constantize
      end

      def sti_name
        name.demodulize
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
      return if @type_value.in?(self.class.type_map.values) # Already normalized

      # Convert symbol to string if needed
      type_key = @type_value.to_sym if @type_value.respond_to?(:to_sym)

      # Map the friendly type to the STI type if it exists in our mapping
      @type_value = self.class.type_map[type_key] if self.class.type_map.key?(type_key)
    end

    def store_in_configuration(*attrs)
      attrs.each do |attr|
        value = instance_variable_get("@#{attr}") || send(attr)
        next if value.nil?

        self.configuration = (configuration || {}).merge(attr.to_s => value)
      end
    end

    def read_from_configuration(*attrs)
      return unless configuration

      attrs.each do |attr|
        next unless configuration.key?(attr.to_s)

        instance_variable_set("@#{attr}", configuration[attr.to_s])
      end
    end
  end
end
