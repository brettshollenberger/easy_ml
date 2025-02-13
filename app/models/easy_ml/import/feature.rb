module EasyML
  module Import
    class Feature
      def self.permitted_keys
        @permitted_keys ||= EasyML::Feature.columns.map(&:name).map(&:to_sym) -
                            EasyML::Export::Feature::UNCONFIGURABLE_COLUMNS.map(&:to_sym)
      end

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

      def self.validate(config, idx)
        extra_keys = config.keys.map(&:to_sym) - permitted_keys
        raise ArgumentError, "Invalid keys in feature config at index #{idx}: #{extra_keys.join(", ")}" unless extra_keys.empty?
        config
      end
    end
  end
end
