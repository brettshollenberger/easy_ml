require "fileutils"
require "polars"
require "date"
require "json"
require_relative "preprocessor/utils"
require_relative "preprocessor/simple_imputer"

module EasyML::Data
  class Preprocessor
    include GlueGun::DSL
    include EasyML::Data::Preprocessor::Utils

    CATEGORICAL_COMMON_MIN = 50
    PREPROCESSING_ORDER = %w[clip mean median constant categorical one_hot ffill custom fill_date add_datepart]

    attribute :directory, :string
    attribute :verbose, :boolean, default: false
    attribute :preprocessing_steps, :hash, default: {}
    def preprocessing_steps=(preprocessing_steps)
      super(standardize_config(preprocessing_steps).with_indifferent_access)
    end

    def fit(df)
      return if df.nil?
      return if preprocessing_steps.keys.none?

      puts "Preprocessing..." if verbose
      imputers = initialize_imputers(
        preprocessing_steps[:training].merge!(preprocessing_steps[:inference] || {})
      )

      did_cleanup = false
      imputers.each do |col, imputers|
        sorted_strategies(imputers).each do |strategy|
          imputer = imputers[strategy]
          unless did_cleanup
            imputer.cleanup
            did_cleanup = true
          end
          if df.columns.map(&:downcase).include?(col.downcase)
            actual_col = df.columns.find { |c| c.downcase == imputer.attribute.downcase }
            imputer.fit(df[actual_col], df)
            if strategy == "clip" # This is the only one to transform during fit
              df[actual_col] = imputer.transform(df[actual_col])
            end
          elsif @verbose
            puts "Warning: Column '#{col}' not found in DataFrame during fit process."
          end
        end
      end
    end

    def postprocess(df, inference: false)
      puts "Postprocessing..." if verbose
      return df if preprocessing_steps.keys.none?

      steps = if inference
                preprocessing_steps[:training].merge(preprocessing_steps[:inference] || {})
              else
                preprocessing_steps[:training]
              end

      df = apply_transformations(df, steps)

      puts "Postprocessing complete." if @verbose
      df
    end

    def statistics
      initialize_imputers(preprocessing_steps[:training]).each_with_object({}) do |(col, strategies), result|
        result[col] = strategies.each_with_object({}) do |(strategy, imputer), col_result|
          col_result[strategy] = imputer.statistics
        end
      end
    end

    def is_fit?
      statistics.any? { |_, col_stats| col_stats.any? { |_, strategy_stats| strategy_stats.present? } }
    end

    def delete
      return unless File.directory?(@directory)

      FileUtils.rm_rf(@directory)
    end

    def move(to)
      old_dir = directory
      current_env = directory.split("/")[-1]
      new_dir = directory.gsub(Regexp.new(current_env), to)

      puts "Moving #{old_dir} to #{new_dir}"
      FileUtils.mv(old_dir, new_dir)
      @directory = new_dir
    end

    private

    def initialize_imputers(config)
      standardize_config(config).each_with_object({}) do |(col, strategies), hash|
        hash[col] ||= {}
        strategies.each do |strategy, options|
          options = {} if options == true

          hash[col][strategy] = EasyML::Data::Preprocessor::SimpleImputer.new(
            strategy: strategy,
            path: directory,
            attribute: col,
            options: options
          )
        end
      end
    end

    def apply_transformations(df, config)
      imputers = initialize_imputers(config)

      standardize_config(config).each do |col, strategies|
        if df.columns.map(&:downcase).include?(col.downcase)
          actual_col = df.columns.find { |c| c.downcase == col.downcase }

          sorted_strategies(strategies).each do |strategy|
            if strategy.to_sym == :categorical && imputers.dig(col, strategy).options.dig("one_hot")
              df = apply_one_hot(df, col, imputers)
            else
              imputer = imputers.dig(col, strategy)
              df[actual_col] = imputer.transform(df[actual_col]) if imputer
            end
          end
        elsif @verbose
          puts "Warning: Column '#{col}' not found in DataFrame during apply_transformations process."
        end
      end

      df
    end

    def apply_one_hot(df, col, imputers)
      cat_imputer = imputers.dig(col, "categorical")
      approved_values = cat_imputer.statistics[:categorical][:value].select do |_k, v|
        v >= cat_imputer.options["categorical_min"]
      end.keys

      # Create one-hot encoded columns
      approved_values.each do |value|
        new_col_name = "#{col}_#{value}".gsub(/-/, "_")
        df = df.with_column(
          df[col].eq(value.to_s).cast(Polars::Int64).alias(new_col_name)
        )
      end

      # Create 'other' column for unapproved values
      other_col_name = "#{col}_other"
      df[other_col_name] = df[col].map_elements do |value|
        approved_values.map(&:to_s).exclude?(value)
      end.cast(Polars::Int64)
      df.drop([col])
    end

    def sorted_strategies(strategies)
      strategies.keys.sort_by do |key|
        PREPROCESSING_ORDER.index(key)
      end
    end

    def prepare_for_imputation(df, col)
      df = df.with_column(Polars.col(col).cast(Polars::Float64))
      df.with_column(Polars.when(Polars.col(col).is_null).then(Float::NAN).otherwise(Polars.col(col)).alias(col))
    end
  end
end

# Where to put this???
#
# def self.stage_required_files
#   required_files.each do |file|
#     git_add(file)
#   end
# end

# def self.git_add(path)
#   command = "git add #{path}"
#   puts command if verbose
#   result = `#{command}`
#   puts result if verbose
# end

# def self.set_verbose(verbose)
#   @verbose = verbose
# end

# def required_files
#   files = Dir.entries(@directory) - %w[. ..]
#   required_file_types = %w[bin]

#   files.select { |file| required_file_types.any? { |ext| file.include?(ext) } }.map do |file|
#     File.join(@directory, file)
#   end
# end
