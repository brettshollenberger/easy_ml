module EasyML
  module Import
    class Dataset
      def self.permitted_keys
        @permitted_keys ||= EasyML::Dataset.columns.map(&:name).map(&:to_sym) -
                            EasyML::Export::Dataset::UNCONFIGURABLE_COLUMNS.map(&:to_sym) +
                            [:columns, :features, :splitter, :datasource]
      end

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

        needs_refresh = false

        # Update existing columns
        columns_config.each do |column_config|
          column_name = column_config["name"]
          existing_column = dataset.columns.find_by(name: column_name)
          
          if existing_column
            old_drop_if_null = existing_column.drop_if_null
            new_drop_if_null = column_config["drop_if_null"]
            
            # Check if drop_if_null has changed
            needs_refresh ||= !new_drop_if_null.nil? && old_drop_if_null != new_drop_if_null
          end

          EasyML::Column.from_config(column_config, dataset, action: :update)
        end

        # Update or create features
        features_config.each do |feature_config|
          EasyML::Feature.from_config(feature_config, dataset, action: :update)
        end

        # Refresh if needed
        dataset.refresh_async if needs_refresh

        dataset
      end

      def self.validate(dataset_config)
        extra_keys = dataset_config.keys.map(&:to_sym) - permitted_keys
        raise ArgumentError, "Invalid dataset keys: #{extra_keys.join(", ")}" unless extra_keys.empty?

        if dataset_config[:splitter].present?
          dataset_config[:splitter] = EasyML::Import::Splitter.validate(dataset_config[:splitter])
        end

        if dataset_config[:columns].present?
          unless dataset_config[:columns].is_a?(Array)
            raise ArgumentError, "Columns configuration must be an array"
          end
          dataset_config[:columns].each_with_index do |col_config, idx|
            unless col_config.is_a?(Hash)
              raise ArgumentError, "Each column configuration must be a hash, at index #{idx}"
            end
            EasyML::Import::Column.validate(col_config, idx)
          end
        end

        if dataset_config[:features].present?
          unless dataset_config[:features].is_a?(Array)
            raise ArgumentError, "Features configuration must be an array"
          end
          dataset_config[:features].each_with_index do |feat_config, idx|
            unless feat_config.is_a?(Hash)
              raise ArgumentError, "Each feature configuration must be a hash, at index #{idx}"
            end
            EasyML::Import::Feature.validate(feat_config, idx)
          end
        end

        dataset_config
      end
    end
  end
end
