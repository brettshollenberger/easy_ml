require_relative "date_converter"
require_relative "polars_column"

module EasyML::Data
  class StatisticsLearner
    include GlueGun::DSL

    attribute :verbose

    def self.learn(df)
      return if df.nil?

      base_stats = describe_to_h(df).deep_symbolize_keys

      # Add basic column statistics first
      df.columns.each_with_object({}) do |col, stats|
        series = df[col]
        field_type = PolarsColumn.determine_type(series)

        stats[col] = {
          field_type: field_type,
          null_count: base_stats[col.to_sym][:null_count].to_i
        }

        # Add type-specific statistics
        case field_type
        when :numeric
          stats[col].merge!(base_stats[col.to_sym])
        when :categorical
          stats[col].merge!(unique_count: series.n_unique)
        when :datetime
          # Only null count needed for datetime (already added above)
        when :text
          # Only null count needed for text (already added above)
        end
      end
    end

    def self.describe_to_h(df)
      init_h = df.describe.to_h
      rows = init_h.values.map(&:to_a)
      keys = rows.first
      column_names = init_h.keys[1..-1]
      column_values = rows[1..-1]
      column_names.zip(column_values).inject({}) do |hash, (col_name, col_values)|
        hash.tap do
          hash[col_name] = Hash[keys.zip(col_values)]
        end
      end
    end
  end
end
