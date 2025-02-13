module EasyML
  module Import
    class Column
      def self.permitted_keys
        @permitted_keys ||= EasyML::Column.columns.map(&:name).map(&:to_sym) -
                            EasyML::Export::Column::UNCONFIGURABLE_COLUMNS.map(&:to_sym)
      end

      def self.from_config(config, dataset, action: :create)
        column_name = config["name"]
        existing_column = dataset.columns.find_by(name: column_name)

        case action
        when :create
          dataset.columns.create(config)
        when :update
          if existing_column
            existing_column.update!(config)
            existing_column
          else
            # Do not create column if it does not exist in the raw dataset
          end
        else
          raise ArgumentError, "Invalid action: #{action}. Must be :create or :update"
        end
      end

      def self.validate(config, idx)
        extra_keys = config.keys.map(&:to_sym) - permitted_keys
        raise ArgumentError, "Invalid keys in column config at index #{idx}: #{extra_keys.join(", ")}" unless extra_keys.empty?
        config
      end
    end
  end
end
