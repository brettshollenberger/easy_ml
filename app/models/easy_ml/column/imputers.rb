module EasyML
  class Column
    class Imputers
      attr_accessor :dataset, :column

      ALLOWED_PARAMS = {
        constant: [:constant],
        categorical: %i[categorical_min one_hot ordinal_encoding],
        most_frequent: %i[one_hot ordinal_encoding],
        mean: [:clip],
        median: [:clip],
      }

      PREPROCESSING_STRATEGIES = {
        float: [
          { value: "ffill", label: "Forward Fill" },
          { value: "mean", label: "Mean" },
          { value: "median", label: "Median" },
          { value: "constant", label: "Constant Value" },
        ],
        integer: [
          { value: "ffill", label: "Forward Fill" },
          { value: "mean", label: "Mean" },
          { value: "median", label: "Median" },
          { value: "constant", label: "Constant Value" },
        ],
        boolean: [
          { value: "ffill", label: "Forward Fill" },
          { value: "most_frequent", label: "Most Frequent" },
          { value: "constant", label: "Constant Value" },
        ],
        datetime: [
          { value: "ffill", label: "Forward Fill" },
          { value: "constant", label: "Constant Value" },
          { value: "today", label: "Current Date" },
        ],
        string: [
          { value: "ffill", label: "Forward Fill" },
          { value: "most_frequent", label: "Most Frequent" },
          { value: "constant", label: "Constant Value" },
        ],
        text: [
          { value: "ffill", label: "Forward Fill" },
          { value: "most_frequent", label: "Most Frequent" },
          { value: "constant", label: "Constant Value" },
        ],
        categorical: [
          { value: "ffill", label: "Forward Fill" },
          { value: "categorical", label: "Categorical" },
          { value: "most_frequent", label: "Most Frequent" },
          { value: "constant", label: "Constant Value" },
        ],
      }.freeze

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
