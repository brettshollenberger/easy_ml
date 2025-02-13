module EasyML
  module Import
    class Splitter
      def self.permitted_keys
        @permitted_keys ||= EasyML::Splitter.columns.map(&:name).map(&:to_sym) -
                            EasyML::Export::Splitter::UNCONFIGURABLE_COLUMNS.map(&:to_sym)
      end

      def self.from_config(config, dataset)
        return nil unless config.present?

        if dataset.splitter.present?
          dataset.splitter.update!(config)
          dataset.splitter
        else
          dataset.create_splitter!(config)
        end
      end

      def self.validate(config)
        return nil unless config.present?

        unless config.is_a?(Hash)
          raise ArgumentError, "Splitter configuration must be a hash"
        end

        extra_keys = config.keys.map(&:to_sym) - permitted_keys
        raise ArgumentError, "Invalid splitter keys: #{extra_keys.join(", ")}" unless extra_keys.empty?

        config
      end
    end
  end
end
