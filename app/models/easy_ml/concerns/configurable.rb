module EasyML
  module Concerns
    module Configurable
      extend ActiveSupport::Concern

      included do
        is_model = ancestors.include?(ActiveRecord::Base)
        self.filter_attributes += [:configuration] if is_model
        class_attribute :configuration_attributes, instance_writer: false, default: []

        after_initialize :read_from_configuration if is_model
        before_save :store_in_configuration if is_model
      end

      class_methods do
        def add_configuration_attributes(*attrs)
          self.configuration_attributes += attrs
          self.configuration_attributes = self.configuration_attributes.uniq

          # Define attr_accessor for each configuration attribute
          attrs.each do |attr|
            attr_accessor attr unless method_defined?(attr)
          end
        end
      end

      private

      def read_from_configuration
        return unless configuration

        self.class.configuration_attributes.each do |attr|
          next unless configuration.key?(attr.to_s)

          instance_variable_set("@#{attr}", configuration[attr.to_s])
        end
      end

      def store_in_configuration
        serialized = self.class.configuration_attributes.each_with_object({}) do |attr, hash|
          value = public_send(attr)
          hash[attr] = serialize_value(value)
        end

        self.configuration = (configuration || {}).merge(serialized)
      end

      def serialize_value(value)
        return value if basic_type?(value)
        return value.to_h if value.respond_to?(:to_h)
        return value.as_json if value.respond_to?(:as_json)

        value.to_s
      end

      def basic_type?(value)
        [String, Symbol, Integer, Float, TrueClass, FalseClass, NilClass, Hash, Array].any? { |type| value.is_a?(type) }
      end
    end
  end
end
