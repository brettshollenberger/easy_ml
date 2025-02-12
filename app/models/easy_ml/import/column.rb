module EasyML
  module Import
    class Column
      def self.from_config(config, dataset, action: :create)
        column_name = config["name"]
        existing_column = dataset.columns.find_by(name: column_name)

        case action
        when :create
          dataset.columns.create!(config)
        when :update
          if existing_column
            existing_column.update!(config)
            existing_column
          else
            raise EasyML::InvalidConfigurationError, "Column '#{column_name}' not found in dataset"
          end
        else
          raise ArgumentError, "Invalid action: #{action}. Must be :create or :update"
        end
      end
    end
  end
end
