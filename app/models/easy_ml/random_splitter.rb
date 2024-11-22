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
require_relative "splitter"

module EasyML
  class RandomSplitter < EasyML::Splitter
    validates :train_ratio, presence: true, numericality: { greater_than: 0, less_than: 1 }
    validates :valid_ratio, presence: true, numericality: { greater_than: 0, less_than: 1 }
    validates :test_ratio, presence: true, numericality: { greater_than: 0, less_than: 1 }
    validate :ratios_sum_to_one

    after_initialize :set_defaults

    attr_accessor :train_ratio, :valid_ratio, :test_ratio, :seed
    add_configuration_attributes :train_ratio, :valid_ratio, :test_ratio, :seed

    def split(df)
      # Set random seed if provided for reproducibility
      if seed
        Polars.random_seed(seed.to_i)
      end

      # Get total number of rows
      n_rows = df.height

      # Generate random numbers for each row
      random_col = "random_split"
      df_with_random = df.with_columns([
        Polars.lit(Array.new(n_rows) { Random.rand }).alias(random_col),
      ])

      # Calculate split thresholds
      train_threshold = train_ratio
      valid_threshold = train_ratio + valid_ratio

      # Split the dataframe
      train_df = df_with_random.filter(Polars.col(random_col) < train_threshold).drop(random_col)
      valid_df = df_with_random.filter(
        (Polars.col(random_col) >= train_threshold) & (Polars.col(random_col) < valid_threshold)
      ).drop(random_col)
      test_df = df_with_random.filter(Polars.col(random_col) >= valid_threshold).drop(random_col)

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
      unless (sum - 1.0).abs < 1e-10 # Using small epsilon for float comparison
        errors.add(:base, "Split ratios must sum to 1.0 (got #{sum})")
      end
    end
  end
end
