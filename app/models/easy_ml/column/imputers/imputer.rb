module EasyML
  class Column
    class Imputers
      class Imputer
        attr_accessor :dataset, :column, :preprocessing_step, :allowed_adapters

        def initialize(column, preprocessing_step, allowed_adapters = [])
          @column = column
          @dataset = column.dataset
          @preprocessing_step = preprocessing_step.with_indifferent_access
          @allowed_adapters = allowed_adapters.map(&:to_sym)
        end

        def inspect
          "#<#{self.class.name} adapters=#{adapters.map(&:inspect).join(", ")}>"
        end

        def exprs
          adapters.map(&:expr)
        end

        def ordered_adapters
          [
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
            EmbeddingEncoder,
          ]
        end

        def allowed?(adapter)
          allowed_adapters.empty? || allowed_adapters.include?(adapter.class.name.split("::").last.underscore.to_sym)
        end

        def adapters
          @adapters ||= ordered_adapters.map { |klass| klass.new(column, preprocessing_step) }.select { |adapter| allowed?(adapter) && adapter.applies? }
        end

        def description
          adapters.map(&:description).compact.join(", ")
        end

        def anything?
          adapters.any?
        end

        def transform(df)
          return df unless anything?

          adapters.reduce(df) do |df, adapter|
            next df if df.columns.exclude?(column.name)

            adapter.transform(df)
          end
        end

        def clip(df)
          return df unless adapters.map(&:class).include?(Clip)

          EasyML::Column::Imputers::Clip.new(column, preprocessing_step).transform(df)
        end

        def decode_labels(df)
          return df unless adapters.map(&:class).include?(OrdinalEncoder)

          EasyML::Column::Imputers::OrdinalEncoder.new(column, preprocessing_step).decode_labels(df)
        end
      end
    end
  end
end
