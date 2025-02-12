module EasyML
  module Export
    class Column
      UNCONFIGURABLE_COLUMNS = %w(
        id
        feature_id
        dataset_id
        last_datasource_sha
        last_feature_sha
        learned_at
        is_learning
        configuration_changed_at
        statistics
        sample_values
        in_raw_dataset
        created_at
        updated_at
      ).freeze

      def self.to_config(column)
        column.as_json.except(*UNCONFIGURABLE_COLUMNS).deep_compact.with_indifferent_access
      end
    end
  end
end
