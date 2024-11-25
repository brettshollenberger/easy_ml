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
            attr_accessor attr
          end
        end
      end

      private

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
