module EasyML
  module Export
    class Model
      UNCONFIGURABLE_COLUMNS = %w(
        id
        created_at
        updated_at
        dataset_id
        refreshed_at
        sha
      ).freeze

      def self.to_config(model)
        {
          model: model.as_json.except(*UNCONFIGURABLE_COLUMNS).merge!(
            weights: model.weights,
            dataset: model.dataset.to_config["dataset"],
          ),
        }.with_indifferent_access
      end
    end
  end
end
