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
        created_at
        updated_at
      ).freeze

      def self.to_config(column)
        column.as_json.except(*UNCONFIGURABLE_COLUMNS)
      end
    end
  end
end
