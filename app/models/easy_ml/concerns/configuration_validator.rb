module EasyML
  module Concerns
    module ConfigurationValidator
      extend ActiveSupport::Concern

      included do
        validate :validate_splitter_configuration
        validate :validate_transforms
      end

      private

      def validate_splitter_configuration
        return unless configuration&.dig(:splitter)

        splitter_config = configuration[:splitter]
        case splitter_config[:type].to_s
        when "date"
          validate_date_splitter(splitter_config)
        end
      end

      def validate_date_splitter(config)
        required_fields = %i[today date_col months_test months_valid]
        missing_fields = required_fields.select { |field| config[field].blank? }

        return unless missing_fields.any?

        errors.add(:configuration, "Missing required fields for date splitter: #{missing_fields.join(", ")}")
      end

      def validate_transforms
        return if transforms.nil?

        unless transforms.is_a?(String) && Object.const_defined?(transforms)
          errors.add(:transforms, "must be a valid class name that includes EasyML::Transforms")
        end

        klass = transforms.constantize
        return if klass.included_modules.include?(EasyML::Transforms)

        errors.add(:transforms, "class must include EasyML::Transforms")
      end
    end
  end
end
