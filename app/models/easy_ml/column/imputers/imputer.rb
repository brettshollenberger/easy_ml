module EasyML
  class Column
    class Imputers
      class Imputer
        attr_accessor :dataset, :column, :preprocessing_step

        ORDERED_ADAPTERS = [
          Clip,
          Mean,
          Median,
          Constant,
          Ffill,
          Categorical,
          MostFrequent,
          Today,
          OneHotEncoder,
          OrdinalEncoder,
        ]

        def initialize(column, preprocessing_step)
          @column = column
          @dataset = column.dataset
          @preprocessing_step = preprocessing_step.with_indifferent_access
          validate_preprocessing_step!
        end

        def inspect
          "#<#{self.class.name} adapters=#{adapters.map(&:inspect).join(", ")}>"
        end

        def adapters
          @adapters ||= ORDERED_ADAPTERS.map { |klass| klass.new(column, preprocessing_step) }.select(&:applies?)
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

        private

        def validate_preprocessing_step!
          validate_params!
          validate_method!
        end

        def validate_params!
          return unless preprocessing_step[:params]

          preprocessing_step[:params].keys.each do |param|
            unless Imputers.supported_params.include?(param.to_sym)
              raise ArgumentError, "Unsupported preprocessing parameter '#{param}'. Supported parameters are: #{Imputers.supported_params.join(", ")}"
            end
          end
        end

        def validate_method!
          return unless preprocessing_step[:method]

          unless Imputers.supported_methods.include?(preprocessing_step[:method].to_sym)
            raise ArgumentError, "Unsupported preprocessing method '#{preprocessing_step[:method]}'. Supported methods are: #{Imputers.supported_methods.join(", ")}"
          end
        end
      end
    end
  end
end

require_relative "clip"
require_relative "mean"
require_relative "median"
