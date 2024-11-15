require "spec_helper"

RSpec.describe EasyML::Data::Preprocessor do
  before(:each) do
    @df = Polars::DataFrame.new({
                                  id: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
                                  rev: [0, 0, 100, 200, 0, 300, 400, 500, nil, nil],
                                  annual_revenue: [300, 400, 5000, 10_000, 20_000, 30, nil, nil, nil, nil],
                                  group: %w[a a a b b a c c] + [nil, nil],
                                  points: [1.0, 2.0, 0.1, 0.8, nil, 0.1, 0.4, 0.9, nil, nil],
                                  created_date: %w[2021-01-01 2021-01-01 2022-02-02 2024-01-01 2024-06-15 2024-07-01
                                                   2024-08-01 2024-09-01] + [nil, nil]
                                })

    # Convert the 'created_date' column to datetime
    @df.with_column(
      Polars.col("created_date").str.strptime(Polars::Datetime, "%Y-%m-%d").alias("created_date")
    )

    @datasource = EasyML::Datasource.create(
      name: "dataset",
      datasource_type: :polars,
      df: @df
    )

    @dataset = EasyML::Dataset.create(
      name: "My Dataset",
      datasource: @datasource,
      splitter: {
        date: {
          today: EST.parse("2024-10-01"),
          date_col: "created_date",
          months_test: 2,
          months_valid: 2
        }
      }
    )
    @dataset.refresh # Will create columns

    @dataset.columns.find_by(name: "rev").update(is_target: true)
  end

  it "preprocesses mean" do
    @dataset.columns.find_by(name: "annual_revenue").update(
      preprocessing_steps: {
        training: {
          method: :mean
        }
      }
    )

    @dataset.refresh

    statistics_mean = @dataset.statistics.dig("raw", "annual_revenue", "mean")
    raw_dataset = @dataset.raw.read(:all)
    null_mask = raw_dataset["annual_revenue"].is_null
    expect(statistics_mean).to eq @dataset.train["annual_revenue"].mean
    expect(@dataset.data[null_mask]["annual_revenue"].to_a).to all(eq statistics_mean)
    expect(@dataset.data[null_mask].count).to eq 4
  end

  it "preprocesses median" do
    @dataset.columns.find_by(name: "annual_revenue").update(
      preprocessing_steps: {
        training: {
          method: :median
        }
      }
    )

    @dataset.refresh

    statistics_median = @dataset.statistics.dig("raw", "annual_revenue", "median")
    raw_dataset = @dataset.raw.read(:all)
    null_mask = raw_dataset["annual_revenue"].is_null
    expect(statistics_median).to eq @dataset.train["annual_revenue"].median
    expect(@dataset.data[null_mask]["annual_revenue"].to_a).to all(eq statistics_median)
    expect(@dataset.data[null_mask].count).to eq 4
  end

  it "preprocesses ffill" do
    @dataset.columns.find_by(name: "created_date").update(
      preprocessing_steps: {
        training: {
          method: :ffill
        }
      }
    )

    @dataset.refresh

    statistics_last_val = @dataset.statistics.dig("raw", "created_date", "last_value")
    last_train_val = @dataset.train.sort("created_date")["created_date"][-1]
    raw_dataset = @dataset.raw.read(:all)
    null_mask = raw_dataset["created_date"].is_null
    expect(UTC.parse(statistics_last_val)).to eq last_train_val
    expect(@dataset.data[null_mask]["created_date"].to_a).to all(eq last_train_val)
    expect(@dataset.data[null_mask].count).to eq 2
  end

  it "preprocesses most frequent" do
    @dataset.columns.find_by(name: "group").update(
      preprocessing_steps: {
        training: {
          method: :most_frequent
        }
      }
    )

    @dataset.refresh

    statistics_most_freq = @dataset.statistics.dig("raw", "group", "most_frequent_value")
    train_most_freq = @dataset.train["group"].mode.to_a.first
    raw_dataset = @dataset.raw.read(:all)
    null_mask = raw_dataset["group"].is_null
    expect(statistics_most_freq).to eq train_most_freq
    expect(@dataset.data[null_mask]["group"].to_a).to all(eq train_most_freq)
    expect(@dataset.data[null_mask].count).to eq 2
  end

  it "preprocesses constant" do
    @dataset.columns.find_by(name: "group").update(
      preprocessing_steps: {
        training: {
          method: :constant,
          params: {
            constant: "c"
          }
        }
      }
    )

    @dataset.refresh
    expect(@dataset.data["group"][-2..-1].to_a).to all(eq "c")
  end

  it "preprocesses mean with clipping" do
    @dataset.columns.find_by(name: "annual_revenue").update(
      preprocessing_steps: {
        training: {
          method: :mean,
          params: {
            clip: {
              min: 0,
              max: 10
            }
          }
        }
      }
    )

    # expect(@dataset.statistics.dig("raw", "mean"))
    @dataset.refresh

    mean_raw = @dataset.statistics.dig("raw", "annual_revenue", "mean")
    mean_processed = @dataset.statistics.dig("processed", "annual_revenue", "mean")
    expect(mean_raw).to be > mean_processed
    expect(mean_raw).to eq @dataset.raw.read(:train)["annual_revenue"].mean
    expect(mean_processed).to eq 10
    expect(@dataset.data["annual_revenue"].to_a).to all(eq 10)
  end

  it "preprocesses categorical with min" do
    @dataset.columns.find_by(name: "group").update(
      preprocessing_steps: {
        training: {
          method: :categorical,
          params: {
            categorical_min: 3
          }
        }
      }
    )

    # expect(@dataset.statistics.dig("raw", "mean"))
    @dataset.refresh
    values = @dataset.data["group"].value_counts.to_a.map(&:values).to_h
    expect(values).to match(hash_including({ "other" => 6, "a" => 4 }))
  end
end
