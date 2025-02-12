module EasyML
  module Export
    class Model
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

        config.with_indifferent_access
      end
    end
  end
end
