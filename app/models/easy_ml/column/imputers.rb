module EasyML
  class Column
    class Imputers
      attr_accessor :dataset, :column

      def initialize(column)
        @column = column
        @dataset = column.dataset
      end

      def imputers
        return {} if column.preprocessing_steps.blank?

        @imputers ||= column.preprocessing_steps.keys.reduce({}) do |hash, key|
          hash.tap do
            hash[key.to_sym] = Imputer.new(
              column,
              column.preprocessing_steps[key],
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

      private

      def imputer_group(key)
        imputers.dig(key.to_sym) || NullImputer.new
      end
    end
  end
end
