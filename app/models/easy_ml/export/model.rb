module EasyML
  module Export
    class Model
      using EasyML::DeepCompact

      UNCONFIGURABLE_COLUMNS = %w(
        id
        dataset_id
        model_file_id
        root_dir
        file
        sha
        last_trained_at
        is_training
        created_at
        updated_at
        slug
        early_stopping_rounds
      ).freeze

      def self.to_config(model, include_dataset: true)
        config = {
          model: model.as_json.except(*UNCONFIGURABLE_COLUMNS).merge!(
            weights: model.weights,
          ),
        }

        if include_dataset
          config[:model][:dataset] = model.dataset.to_config["dataset"]
        end

        if model.retraining_job.present?
          config[:model][:retraining_job] = EasyML::Export::RetrainingJob.to_config(model.retraining_job)
        end

        config.deep_compact.with_indifferent_access
      end
    end
  end
end
