module EasyML
  module Export
    class Dataset
      UNCONFIGURABLE_COLUMNS = %w(
        id
        created_at
        updated_at
        statistics
        root_dir
        refreshed_at
        sha
        statistics
        datasource_id
        last_datasource_sha
        num_rows
        schema
        raw_schema
        status
      ).freeze

      def self.to_config(dataset)
        dataset.fully_reload

        {
          dataset: dataset.as_json.except(*UNCONFIGURABLE_COLUMNS).merge!(
            splitter: dataset.splitter&.to_config,
            datasource: dataset.datasource.to_config,
            columns: dataset.columns.map(&:to_config),
            features: dataset.features.map(&:to_config),
          ),
        }.deep_compact.with_indifferent_access
      end
    end
  end
end
