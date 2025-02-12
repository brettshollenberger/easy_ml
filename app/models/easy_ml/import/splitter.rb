module EasyML
  module Import
    class Splitter
      def self.from_config(config, dataset)
        return nil unless config.present?

        if dataset.splitter.present?
          dataset.splitter.update!(config)
          dataset.splitter
        else
          dataset.create_splitter!(config)
        end
      end
    end
  end
end
