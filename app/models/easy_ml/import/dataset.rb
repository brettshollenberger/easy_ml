module EasyML
  module Import
    class Dataset
      def self.from_config(json_config, action: nil, dataset: nil)
        raise ArgumentError, "Target dataset must be specified" if action == :update && dataset.nil?

        config = json_config.is_a?(String) ? JSON.parse(json_config) : json_config
        dataset_config = config["dataset"]

        # Extract configs for related models
        datasource_config = dataset_config.delete("datasource")
        splitter_config = dataset_config.delete("splitter")
        columns_config = dataset_config.delete("columns") || []
        features_config = dataset_config.delete("features") || []

        if action == :create
          name = dataset_config["name"]
          dataset = EasyML::Dataset.find_by(name: name)
          action = dataset.present? ? :update : :create
        end
        raise ArgumentError, "Action must be specified" unless action.present?

        if action == :create
          create_dataset(
            dataset_config,
            datasource_config,
            splitter_config,
            columns_config,
            features_config
          )
        elsif action == :update
          update_dataset(
            dataset,
            dataset_config,
            columns_config,
            features_config
          )
        else
          raise ArgumentError, "Invalid action: #{action}. Must be :create or :update"
        end
      end

      private

      def self.create_dataset(dataset_config, datasource_config, splitter_config, columns_config, features_config)
        # Create new datasource
        datasource = EasyML::Datasource.find_or_create_by(name: datasource_config["name"]) do |ds|
          ds.assign_attributes(datasource_config)
        end
        datasource.update!(datasource_config)

        # Create new dataset
        dataset = EasyML::Dataset.create!(
          dataset_config.merge(datasource: datasource)
        )

        # Create splitter if config exists
        EasyML::Splitter.from_config(splitter_config, dataset) if splitter_config.present?

        # Create columns
        columns_config.each do |column_config|
          EasyML::Column.from_config(column_config, dataset, action: :create)
        end

        # Create features
        features_config.each do |feature_config|
          EasyML::Feature.from_config(feature_config, dataset, action: :create)
        end

        dataset
      end

      def self.update_dataset(dataset, dataset_config, columns_config, features_config)
        # Update dataset attributes except name (preserve original name)
        dataset.update!(dataset_config.except("name", "datasource"))

        # Update existing columns
        columns_config.each do |column_config|
          EasyML::Column.from_config(column_config, dataset, action: :update)
        end

        # Update or create features
        features_config.each do |feature_config|
          EasyML::Feature.from_config(feature_config, dataset, action: :update)
        end

        dataset
      end
    end
  end
end
