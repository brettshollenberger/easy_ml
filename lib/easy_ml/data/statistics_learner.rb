require_relative "date_converter"
require_relative "polars_column"

module EasyML::Data
  class StatisticsLearner
    attr_accessor :verbose

    def initialize(options = {})
      @verbose = options[:verbose]
    end

    def self.learn(raw, processed)
      output = { raw: learn_split(raw) }
      output[:processed] = learn_split(processed) if processed.data.present?
      output
    end

    def self.learn_split(split)
      df = split.read(:all)
      train_df = split.read(:train)
      all_stats = learn_df(df)
      train_stats = learn_df(train_df)

      all_stats.reduce({}) do |output, (k, _)|
        output.tap do
          output[k] = all_stats[k].slice(:num_rows, :null_count, :unique_count, :counts).merge!(
            train_stats[k].slice(:mean, :median, :min, :max, :std, :last_value, :most_frequent_value)
          )
        end
      end
    end

    def self.learn_df(df)
      return if df.nil?

      base_stats = describe_to_h(df).deep_symbolize_keys

      # Add basic column statistics first
      df.columns.each_with_object({}) do |col, stats|
        series = df[col]
        return {} if series.dtype == Polars::Null
        field_type = PolarsColumn.determine_type(series)

        stats[col] = {
          num_rows: series.shape,
          null_count: base_stats[col.to_sym][:null_count].to_i,
        }

        # Add type-specific statistics
        case field_type
        when :integer, :float
          allowed_attrs = if id_column?(col)
              %i[field_type null_count min max]
            else
              base_stats[col.to_sym].keys
            end
          stats[col].merge!(base_stats[col.to_sym].slice(*allowed_attrs))
        when :categorical, :string, :text, :boolean
          stats[col].merge!(most_frequent_value: series.mode.sort.to_a&.first)
          if field_type == :categorical
            stats[col].merge!(
              unique_count: series.n_unique,
              counts: Hash[series.value_counts.to_hashes.map(&:values)],
            )
          end
        when :datetime
          stats[col].merge!(
            unique_count: series.n_unique,
            last_value: series.sort[-1],
          )
        end
      end
    end

    def self.id_column?(column)
      col = column.to_s.downcase
      col.match?(/^id$/) || col.match?(/.*_id/)
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
