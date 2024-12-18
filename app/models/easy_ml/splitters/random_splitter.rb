# == Schema Information
#
# Table name: easy_ml_splitters
#
#  id            :bigint           not null, primary key
#  splitter_type :string           not null
#  configuration :json
#  dataset_id    :bigint           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
require_relative "base_splitter"

module EasyML
  module Splitters
    class RandomSplitter < BaseSplitter
      validates :train_ratio, presence: true, numericality: { greater_than: 0, less_than: 1 }
      validates :valid_ratio, presence: true, numericality: { greater_than: 0, less_than: 1 }
      validates :test_ratio, presence: true, numericality: { greater_than: 0, less_than: 1 }
      validate :ratios_sum_to_one

      attr_accessor :train_ratio, :valid_ratio, :test_ratio, :seed

      add_configuration_attributes :train_ratio, :valid_ratio, :test_ratio, :seed

      def split_df(df)
        set_defaults

        # Set random seed if provided for reproducibility
        rng = seed ? Random.new(seed.to_i) : Random.new

        # Get total number of rows
        n_rows = df.height

        # Generate a deterministic random order based on the seed
        shuffled_indices = (0...n_rows).to_a.shuffle(random: rng || Random.new)

        # Calculate split sizes
        train_size = (n_rows * train_ratio).floor
        valid_size = (n_rows * valid_ratio).floor

        # Split indices
        train_indices = shuffled_indices[0...train_size]
        valid_indices = shuffled_indices[train_size...(train_size + valid_size)]
        test_indices = shuffled_indices[(train_size + valid_size)..]

        # Add an index column to filter
        df_with_index = df.with_columns([
          Polars.arange(0, n_rows).alias("index"),
        ])

        # Filter rows by index for train, validation, and test sets
        train_df = df_with_index.filter(Polars.col("index").is_in(train_indices)).drop("index")
        valid_df = df_with_index.filter(Polars.col("index").is_in(valid_indices)).drop("index")
        test_df = df_with_index.filter(Polars.col("index").is_in(test_indices)).drop("index")

        [train_df, valid_df, test_df]
      end

      private

      def set_defaults
        self.train_ratio ||= 0.6
        self.valid_ratio ||= 0.2
        self.test_ratio ||= 0.2
      end

      def ratios_sum_to_one
        return unless train_ratio && valid_ratio && test_ratio

        sum = train_ratio + valid_ratio + test_ratio
        return if (sum - 1.0).abs < 1e-10 # Using small epsilon for float comparison

        errors.add(:base, "Split ratios must sum to 1.0 (got #{sum})")
      end
    end
  end
end
