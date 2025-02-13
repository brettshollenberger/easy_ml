module EasyML
  module Import
    class RetrainingJob
      def self.permitted_keys
        @permitted_keys ||= EasyML::RetrainingJob.columns.map(&:name).map(&:to_sym) -
                            EasyML::Export::RetrainingJob::UNCONFIGURABLE_COLUMNS.map(&:to_sym)
      end

      def self.from_config(config, model)
        existing_job = model.get_retraining_job
        existing_job.update!(config)
        existing_job
      end

      def self.validate(config)
        return nil unless config.present?

        unless config.is_a?(Hash)
          raise ArgumentError, "Retraining job configuration must be a hash"
        end

        extra_keys = config.keys.map(&:to_sym) - permitted_keys
        raise ArgumentError, "Invalid retraining job keys: #{extra_keys.join(", ")}" unless extra_keys.empty?

        config
      end
    end
  end
end
