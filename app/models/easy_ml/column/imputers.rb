module EasyML
  class Column
    class Imputers
      attr_accessor :dataset, :column

      ALLOWED_PARAMS = {
        constant: [:constant],
        categorical: %i[categorical_min one_hot ordinal_encoding],
        most_frequent: %i[one_hot ordinal_encoding],
        embedding: %i[llm model preset dimensions],
        mean: [:clip],
        median: [:clip],
      }

      LABELS = {
        ffill: "Forward Fill",
        categorical: "Categorical",
        mean: "Mean",
        median: "Median",
        constant: "Constant Value",
        most_frequent: "Most Frequent",
        today: "Current Date",
        embedding: "Text Embedding",
      }

      PREPROCESSING_STRATEGIES = {
        float: %w(ffill mean median constant),
        integer: %w(ffill mean median constant),
        boolean: %w(ffill most_frequent constant),
        datetime: %w(ffill today constant),
        string: %w(embedding ffill most_frequent constant),
        text: %w(embedding ffill most_frequent constant),
        categorical: %w(embedding ffill categorical most_frequent constant),
      }.transform_values do |strategies|
        strategies.map do |strategy|
          {
            value: strategy,
            label: LABELS[strategy.to_sym],
          }
        end
      end

      def self.constants
        {
          preprocessing_strategies: PREPROCESSING_STRATEGIES,
        }
      end

      def self.params_by_class
        @params_by_class ||= {}
      end

      def self.methods_by_class
        @methods_by_class ||= {}
      end

      def self.supported_params
        @supported_params ||= []
      end

      def self.supported_methods
        @supported_methods ||= []
      end

      def initialize(column, imputers: [])
        @column = column
        @dataset = column.dataset
        @_imputers = imputers
      end

      class << self
        def supported_params
          @supported_params ||= []
        end

        def supported_methods
          @supported_methods ||= []
        end
      end

      def imputers
        return {} if column.preprocessing_steps.blank?

        @imputers ||= column.preprocessing_steps.keys.reduce({}) do |hash, key|
          hash.tap do
            hash[key.to_sym] = Imputer.new(
              column,
              column.preprocessing_steps[key],
              @_imputers
            )
          end
        end
      end

      def training
        @training ||= imputer_group(:training)
      end

      def inference
        @inference ||= imputer_group(:inference)
      end

      def preprocessing_descriptions
        return [] if column.preprocessing_steps.blank?

        [training.description].compact
      end

      private

      def imputer_group(key)
        imputers.dig(key.to_sym) || NullImputer.new
      end
    end
  end
end
