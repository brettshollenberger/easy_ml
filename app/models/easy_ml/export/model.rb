module EasyML
  module Export
    class Model
      UNCONFIGURABLE_COLUMNS = %w(
        id
        dataset_id
        created_at
        updated_at
        refreshed_at
        sha
      ).freeze

      def self.to_config(model)
        model.fully_reload

        {
          model: model.as_json.except(*UNCONFIGURABLE_COLUMNS).merge!(
            dataset: EasyML::Export::Dataset.to_config(model.dataset)["dataset"],
            weights: model.weights,
          ),
        }.with_indifferent_access
      end
    end
  end
end
