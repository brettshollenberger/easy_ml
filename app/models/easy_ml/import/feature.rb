module EasyML
  module Import
    class Feature
      def self.from_config(config, dataset, action: :create)
        feature_name = config["name"]
        existing_feature = dataset.features.find_by(name: feature_name)

        case action
        when :create
          dataset.features.create!(config)
        when :update
          if existing_feature
            existing_feature.update!(config)
            existing_feature
          else
            # Features can be added during update, unlike columns
            dataset.features.create!(config)
          end
        else
          raise ArgumentError, "Invalid action: #{action}. Must be :create or :update"
        end
      end
    end
  end
end
