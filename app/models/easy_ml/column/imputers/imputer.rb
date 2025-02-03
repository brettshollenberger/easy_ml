module EasyML
  class Column
    class Imputers
      class Imputer
        attr_accessor :dataset, :column, :preprocessing_step

        ADAPTERS = [
          Clip,
          Mean,
        ].freeze

        def initialize(column, preprocessing_step)
          @column = column
          @dataset = column.dataset
          @preprocessing_step = preprocessing_step.with_indifferent_access
        end

        def adapters
          @adapters ||= ADAPTERS.map { |klass| klass.new(column, preprocessing_step) }.select(&:applies?)
        end

        def imputers
          return nil if column.preprocessing_steps.blank?

          @imputers ||= column.preprocessing_steps.keys.reduce({}) do |hash, key|
            hash[key.to_sym] = Imputer.new(
              column: column,
              preprocessing_step: column.preprocessing_steps[key],
            )
          end
        end

        def anything?
          adapters.any?
        end

        def transform(df)
          return df unless anything?

          adapters.reduce(df) do |df, adapter|
            adapter.transform(df)
          end
        end

        def clip(df)
          return df unless adapters.map(&:class).include?(Clip)

          EasyML::Column::Imputers::Clip.new(column, preprocessing_step).transform(df)
        end

        def mean(df)
          return df unless adapters.map(&:class).include?(Mean)

          EasyML::Column::Imputers::Mean.new(column, preprocessing_step).transform(df)
        end
      end
    end
  end
end
