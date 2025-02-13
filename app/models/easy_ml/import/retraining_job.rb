module EasyML
  module Import
    class RetrainingJob
      def self.from_config(config, model)
        existing_job = model.get_retraining_job
        existing_job.update!(config)
        existing_job
      end
    end
  end
end
