module EasyML
  module Export
    class RetrainingJob
      using EasyML::DeepCompact

      UNCONFIGURABLE_COLUMNS = %w(
        id
        model_id
        last_tuning_at
        last_run_at
        created_at
        updated_at
      ).freeze

      def self.to_config(retraining_job)
        retraining_job.as_json.except(*UNCONFIGURABLE_COLUMNS).deep_compact.with_indifferent_access
      end
    end
  end
end
