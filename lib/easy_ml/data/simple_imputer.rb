require "active_support/core_ext/hash/deep_transform_values"
require "numo/narray"
require "json"

module EasyML
  module Data
    class SimpleImputer
      attr_reader :statistics
      attr_accessor :path, :attribute, :strategy, :options

      def initialize(strategy: "mean", path: nil, attribute: nil, options: {}, statistics: {}, &block)
        @strategy = strategy.to_sym
        @path = path
        @attribute = attribute
        @options = options || {}
        apply_defaults
        @statistics = statistics || {}
        deep_symbolize_keys!
        return unless block_given?

        instance_eval(&block)
      end

      def deep_symbolize_keys!
        @statistics = @statistics.deep_symbolize_keys
      end

      def apply_defaults
        @options[:date_column] ||= "CREATED_DATE"

        if strategy == :categorical
          @options[:categorical_min] ||= 25
        elsif strategy == :custom
          itself = ->(col) { col }
          @options[:fit] ||= itself
          @options[:transform] ||= itself
        end
      end

      def fit(x, df = nil)
        x = validate_input(x)

        fit_values = case @strategy
                     when :mean
                       fit_mean(x)
                     when :median
                       fit_median(x)
                     when :ffill
                       fit_ffill(x, df)
                     when :most_frequent
                       fit_most_frequent(x)
                     when :categorical
                       fit_categorical(x)
                     when :constant
                       fit_constant(x)
                     when :clip
                       fit_no_op(x)
                     when :today
                       fit_no_op(x)
                     when :one_hot
                       fit_no_op(x)
                     when :custom
                       fit_custom(x)
                     else
                       raise ArgumentError, "Invalid strategy: #{@strategy}"
                     end || {}

        @statistics[attribute] ||= {}
        @statistics[attribute][@strategy] = fit_values.merge!(original_dtype: x.dtype)
        @statistics.deep_symbolize_keys
      end

      def transform(x)
        check_is_fitted

        if x.is_a?(Polars::Series)
          transform_polars(x)
        else
          transform_dense(x)
        end
      end

      def transform_polars(x)
        case @strategy
        when :mean, :median
          x.fill_null(@statistics[@strategy])
        when :ffill
          x.fill_null(@statistics[:last_value])
        when :most_frequent
          x.fill_null(@statistics[:most_frequent_value])
        when :constant
          x.fill_null(@options[:constant])
        when :categorical
          allowed_cats = statistics[:allowed_categories]
          df = Polars::DataFrame.new({ x: x })
          df.with_column(
            Polars.when(Polars.col("x").is_in(allowed_cats))
              .then(Polars.col("x"))
              .otherwise(Polars.lit("other"))
              .alias("x")
          )["x"]
        when :clip
          min = options["min"] || 0
          max = options["max"] || 1_000_000_000_000
          if x.null_count != x.len
            x.clip(min, max)
          else
            x
          end
        when :today
          x.fill_null(transform_today(nil))
        when :custom
          if x.null_count == x.len
            x.fill_null(transform_custom(nil))
          else
            x.apply do |val|
              should_transform_custom?(val) ? transform_custom(val) : val
            end
          end
        else
          raise ArgumentError, "Unsupported strategy for Polars::Series: #{@strategy}"
        end
      end

      def file_path
        raise "Need both attribute and path to save/load statistics" unless attribute.present? && path.to_s.present?

        File.join(path, "statistics.json")
      end

      def transform_today(_val)
        EST.now.beginning_of_day
      end

      def fit_custom(x)
        x
      end

      def should_transform_custom?(x)
        if options.key?(:should_transform)
          options[:should_transform].call(x)
        else
          should_transform_default?(x)
        end
      end

      def transform_custom(x)
        raise "Transform required" unless options.key?(:transform)

        options[:transform].call(x)
      end

      private

      def validate_input(x)
        raise ArgumentError, "Input must be a Polars::Series" unless x.is_a?(Polars::Series)

        x
      end

      def fit_mean(x)
        { value: x.mean }
      end

      def fit_median(x)
        { value: x.median }
      end

      def fit_ffill(x, df)
        values = { value: nil, max_date: nil }

        date_col = df[options[:date_column]]
        return if date_col.is_null.all

        sorted_df = df.sort(options[:date_column])
        new_max_date = sorted_df[options[:date_column]].max

        current_max_date = values[:max_date]
        return if current_max_date && current_max_date > new_max_date

        values[:max_date] = [current_max_date, new_max_date].compact.max

        # Get the last non-null value
        last_non_null = sorted_df[x.name].filter(sorted_df[x.name].is_not_null).tail(1).to_a.first
        values[:value] = last_non_null

        values
      end

      def fit_most_frequent(x)
        value_counts = x.filter(x.is_not_null).value_counts
        column_names = value_counts.columns
        column_names[0]
        count_column = column_names[1]

        most_frequent_value = value_counts.sort(count_column, descending: true).row(0)[0]
        { value: most_frequent_value }
      end

      def fit_categorical(x)
        value_counts = x.value_counts
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
          label_decoder: label_decoder
        }
      end

      def fit_no_op(_x)
        {}
      end

      def fit_constant(_x)
        { value: @options[:fill_value] }
      end

      def transform_default(_val)
        @statistics[strategy][:value]
      end

      def should_transform_default?(val)
        checker_method = val.respond_to?(:nan?) ? :nan? : :nil?
        val.send(checker_method)
      end

      def transform_dense(x)
        result = x.map do |val|
          strategy_method = respond_to?("transform_#{strategy}") ? "transform_#{strategy}" : "transform_default"
          checker_method = respond_to?("should_transform_#{strategy}?") ? "should_transform_#{strategy}?" : "should_transform_default?"
          send(checker_method, val) ? send(strategy_method, val) : val
        end

        # Cast the result back to the original dtype
        original_dtype = @statistics[:original_dtype]
        if original_dtype
          result.map { |val| cast_to_dtype(val, original_dtype) }
        else
          result
        end
      end

      def check_is_fitted
        return if %i[clip today custom].include?(strategy)

        pass_check = case strategy
                     when :mean
                       @statistics.dig(:mean).present?
                     when :median
                       @statistics.dig(:median).present?
                     when :ffill
                       @statistics.dig(:last_value).present?
                     when :most_frequent
                       @statistics.dig(:most_frequent_value).present?
                     when :constant
                       options.dig(:constant).present?
                     when :categorical
                       true
                     end

        raise "SimpleImputer has not been fitted yet for #{attribute}##{strategy}" unless pass_check
      end
    end
  end
end
