module EasyML::Data
  class PreprocessingSteps
    module Utils
      def standardize_config(config)
        config.each do |column, strategies|
          next unless strategies.is_a?(Array)

          config[column] = strategies.reduce({}) do |hash, strategy|
            hash.tap do
              hash[strategy] = true
            end
          end
        end
      end
    end
  end
end
