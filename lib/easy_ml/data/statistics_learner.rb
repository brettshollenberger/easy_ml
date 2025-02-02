require_relative "date_converter"
require_relative "polars_column"

module EasyML::Data
  class StatisticsLearner
    attr_accessor :verbose

    def initialize(options = {})
      @verbose = options[:verbose]
    end

    def self.learn(df, dataset, type)
      new(df, dataset, type).learn
    end

    attr_reader :df, :dataset, :type

    def initialize(df, dataset, type)
      @df = df
      @dataset = dataset
      @type = type.to_sym
    end

    def learn
      learn_split(df)
    end

    def learn_split(split)
      df = split.read(:all)
      train_df = split.read(:train)
      all_stats = learn_df(df)
      train_stats = learn_df(train_df)

      all_stats.reduce({}) do |output, (k, _)|
        output.tap do
          output[k] = all_stats[k].slice(:num_rows, :null_count, :unique_count, :counts).merge!(
            train_stats[k].slice(:mean, :median, :min, :max, :std,
                                 :last_value, :most_frequent_value, :last_known_value,
                                 :allowed_categories, :label_encoder, :label_decoder)
          )
        end
      end
    end

    def learn_categorical(df)
      allowed_categories = learn_allowed_categories(df)
      allowed_categories.reduce({}) do |statistics, (col, categories)|
        statistics.tap do
          statistics[col] ||= {}
          statistics[col][:allowed_categories] = categories
          statistics[col].merge!(
            learn_categorical_encoder_decoder(df[col])
          )
        end
      end
    end

    def learn_categorical_encoder_decoder(series)
      value_counts = series.value_counts
      column_names = value_counts.columns
      value_column = column_names[0]
      count_column = column_names[1]

      as_hash = value_counts.select([value_column, count_column]).rows.to_a.to_h.transform_keys(&:to_s)
      label_encoder = as_hash.keys.sort.each.with_index.reduce({}) do |h, (k, i)|
        h.tap do
          h[k] = i
        end
      end
      label_decoder = label_encoder.invert

      {
        value: as_hash,
        label_encoder: label_encoder,
        label_decoder: label_decoder,
      }
    end

    def learn_allowed_categories(df)
      preprocessing_steps = dataset.preprocessing_steps || {}
      preprocessing_steps.deep_symbolize_keys!

      allowed_categories = {}
      (preprocessing_steps[:training] || {}).each_key do |col|
        next unless [
          preprocessing_steps.dig(:training, col, :params, :ordinal_encoding),
          preprocessing_steps.dig(:training, col, :params, :one_hot),
          preprocessing_steps.dig(:training, col, :method).to_sym == :categorical,
        ].any?

        cat_min = preprocessing_steps.dig(:training, col, :params, :categorical_min) || 1
        val_counts = df[col].value_counts
        allowed_categories[col] = val_counts[val_counts["count"] >= cat_min][col].to_a.compact
      end
      allowed_categories
    end

    def last_known_value(df, col, date_col)
      return nil if df.empty? || !df.columns.include?(date_col)

      # Sort by date and get the last non-null value
      sorted_df = df.sort(date_col, reverse: true)
      last_value = sorted_df
        .filter(Polars.col(col).is_not_null)
        .select(col)
        .head(1)
        .item

      last_value
    end

    def learn_df(df)
      return if df.nil?

      stats = learn_base_stats(df, dataset: dataset).stringify_keys
      if type == :raw
        categorical = learn_categorical(df).stringify_keys
        categorical.each { |k, v| stats[k].merge!(v) }
      end
      stats
    end

    def self.learn_df(df, dataset: nil, type: :raw)
      new(df, dataset, type).learn_df(df)
    end

    def learn_base_stats(df, dataset: nil)
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

        if dataset&.date_column.present?
          stats[col][:last_value] = last_value(df, col, dataset.date_column.name)
        end

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
              unique_count: series.cast(:str).n_unique,
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

    def id_column?(column)
      col = column.to_s.downcase
      col.match?(/^id$/) || col.match?(/.*_id/)
    end

    def last_value(df, col, date_col)
      df.filter(Polars.col(col).is_not_null).sort(date_col)[col][-1]
    end

    def describe_to_h(df)
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
