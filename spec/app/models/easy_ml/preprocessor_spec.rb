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
                                                   2024-08-01 2024-09-01] + [nil, nil],
                                })

    # Convert the 'created_date' column to datetime
    @df.with_column(
      Polars.col("created_date").str.strptime(Polars::Datetime, "%Y-%m-%d").alias("created_date")
    )

    @datasource = EasyML::Datasource.create(
      name: "dataset",
      datasource_type: "polars",
      df: @df,
    )

    @dataset = EasyML::Dataset.create(
      name: "My Dataset",
      datasource: @datasource,
      splitter_attributes: {
        splitter_type: "date",
        today: EasyML::Support::EST.parse("2024-10-01"),
        date_col: "created_date",
        months_test: 2,
        months_valid: 2,
      },
    )
    @dataset.unlock!
    @dataset.refresh # Will create columns

    @dataset.columns.find_by(name: "rev").update(is_target: true)
  end

  it "preprocesses mean" do
    @dataset.columns.find_by(name: "annual_revenue").update(
      preprocessing_steps: {
        training: {
          method: :mean,
        },
      },
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
          method: :median,
        },
      },
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
          method: :ffill,
        },
      },
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
          method: :most_frequent,
        },
      },
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
            constant: "c",
          },
        },
      },
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
              max: 10,
            },
          },
        },
      },
    )

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
            categorical_min: 3,
          },
        },
      },
    )

    # expect(@dataset.statistics.dig("raw", "mean"))
    @dataset.refresh
    values = @dataset.data["group"].value_counts.to_a.map(&:values).to_h
    expect(values).to match(hash_including({ "other" => 6, "a" => 4 }))
  end

  # Float tests
  describe "float preprocessing" do
    let(:float_col) { "points" }

    it "preprocesses float with mean" do
      @dataset.columns.find_by(name: float_col).update(
        preprocessing_steps: {
          training: {
            method: :mean,
          },
        },
      )

      @dataset.refresh
      statistics_mean = @dataset.statistics.dig("raw", float_col, "mean")
      null_mask = @dataset.raw.read(:all)[float_col].is_null
      expect(@dataset.data[null_mask][float_col].to_a).to all(eq statistics_mean)
    end

    it "preprocesses float with median" do
      @dataset.columns.find_by(name: float_col).update(
        preprocessing_steps: {
          training: {
            method: :median,
          },
        },
      )

      @dataset.refresh
      statistics_median = @dataset.statistics.dig("raw", float_col, "median")
      null_mask = @dataset.raw.read(:all)[float_col].is_null
      expect(@dataset.data[null_mask][float_col].to_a).to all(eq statistics_median)
    end

    it "preprocesses float with constant" do
      constant_value = 42.0
      @dataset.columns.find_by(name: float_col).update(
        preprocessing_steps: {
          training: {
            method: :constant,
            params: {
              constant: constant_value,
            },
          },
        },
      )

      @dataset.refresh
      null_mask = @dataset.raw.read(:all)[float_col].is_null
      expect(@dataset.data[null_mask][float_col].to_a).to all(eq constant_value)
    end

    it "preprocesses float with mean and clip" do
      @dataset.columns.find_by(name: float_col).update(
        preprocessing_steps: {
          training: {
            method: :mean,
            params: {
              clip: {
                min: 0.3,
                max: 0.7,
              },
            },
          },
        },
      )

      @dataset.refresh
      processed_values = @dataset.data[float_col].to_a
      expect(processed_values.compact).to all(be_between(0.3, 0.7))
    end

    it "preprocesses float with median and clip" do
      @dataset.columns.find_by(name: float_col).update(
        preprocessing_steps: {
          training: {
            method: :median,
            params: {
              clip: {
                min: 0.3,
                max: 0.7,
              },
            },
          },
        },
      )

      @dataset.refresh
      processed_values = @dataset.data[float_col].to_a
      expect(processed_values.compact).to all(be_between(0.3, 0.7))
    end
  end

  # Integer tests
  describe "integer preprocessing" do
    let(:int_col) { "rev" }

    it "preprocesses integer with mean" do
      @dataset.columns.find_by(name: int_col).update(
        preprocessing_steps: {
          training: {
            method: :mean,
          },
        },
      )

      @dataset.refresh
      statistics_mean = @dataset.statistics.dig("raw", int_col, "mean")
      null_mask = @dataset.raw.read(:all)[int_col].is_null
      expect(@dataset.data[null_mask][int_col].to_a).to all(eq statistics_mean.to_i)
    end

    it "preprocesses integer with median" do
      @dataset.columns.find_by(name: int_col).update(
        preprocessing_steps: {
          training: {
            method: :median,
          },
        },
      )

      @dataset.refresh
      statistics_median = @dataset.statistics.dig("raw", int_col, "median")
      null_mask = @dataset.raw.read(:all)[int_col].is_null
      expect(@dataset.data[null_mask][int_col].to_a).to all(eq statistics_median.to_i)
    end

    it "preprocesses integer with constant" do
      constant_value = 42
      @dataset.columns.find_by(name: int_col).update(
        preprocessing_steps: {
          training: {
            method: :constant,
            params: {
              constant: constant_value,
            },
          },
        },
      )

      @dataset.refresh
      null_mask = @dataset.raw.read(:all)[int_col].is_null
      expect(@dataset.data[null_mask][int_col].to_a).to all(eq constant_value)
    end

    it "preprocesses integer with mean and clip" do
      @dataset.columns.find_by(name: int_col).update(
        preprocessing_steps: {
          training: {
            method: :mean,
            params: {
              clip: {
                min: 100,
                max: 300,
              },
            },
          },
        },
      )

      @dataset.refresh
      processed_values = @dataset.data[int_col].to_a
      expect(processed_values.compact).to all(be_between(100, 300))
    end
  end

  # Boolean, Datetime, String tests
  describe "other data types preprocessing" do
    before(:each) do
      @df_with_bool = @df.with_column(
        Polars.lit([true, false, true, false, nil, true, false, true, nil, nil]).alias("bool_col")
      )
      @datasource.update(df: @df_with_bool)
      @dataset.refresh
    end

    it "preprocesses boolean with most frequent" do
      @dataset.columns.find_by(name: "bool_col").update(
        preprocessing_steps: {
          training: {
            method: :most_frequent,
          },
        },
      )

      @dataset.refresh
      most_frequent = @dataset.statistics.dig("raw", "bool_col", "most_frequent_value")
      null_mask = @dataset.raw.read(:all)["bool_col"].is_null
      expect(@dataset.data[null_mask]["bool_col"].to_a).to all(eq most_frequent)
    end

    it "preprocesses boolean with constant" do
      @dataset.columns.find_by(name: "bool_col").update(
        preprocessing_steps: {
          training: {
            method: :constant,
            params: {
              constant: true,
            },
          },
        },
      )

      @dataset.refresh
      null_mask = @dataset.raw.read(:all)["bool_col"].is_null
      expect(@dataset.data[null_mask]["bool_col"].to_a).to all(eq true)
    end

    it "preprocesses datetime with today" do
      today = UTC.today.beginning_of_day
      @dataset.columns.find_by(name: "created_date").update(
        preprocessing_steps: {
          training: {
            method: :today,
          },
        },
      )

      @dataset.refresh
      null_mask = @dataset.raw.read(:all)["created_date"].is_null
      filled_dates = @dataset.data[null_mask]["created_date"].to_a
      expect(filled_dates.map { |d| d.to_date }).to all(eq today)
    end
  end

  # Categorical tests
  describe "categorical preprocessing" do
    it "preprocesses categorical with one_hot encoding" do
      @dataset.columns.find_by(name: "group").update(
        preprocessing_steps: {
          training: {
            method: :categorical,
            params: {
              one_hot: true,
            },
          },
        },
      )

      @dataset.refresh
      # Group c isn't in the training set
      expect(@dataset.data.columns).to include("group_a", "group_b", "group_other")
      # We don't add one_hot columns to the official columns join
      expect(@dataset.columns.map(&:name)).to_not include("group_a", "group_b", "group_other")
      expect(@dataset.columns.map(&:name)).to include("group")
    end

    it "preprocesses categorical with ordinal encoding" do
      @dataset.columns.find_by(name: "group").update(
        preprocessing_steps: {
          training: {
            method: :categorical,
            params: {
              ordinal_encoding: true,
            },
          },
        },
      )

      @dataset.refresh
      expect(@dataset.data["group"].to_a.uniq.sort).to all(be_a(Integer))
      expect(@dataset.columns.find_by(name: "group").datatype).to eq "text"
    end

    it "preprocesses categorical with min count and one_hot encoding" do
      @dataset.columns.find_by(name: "group").update(
        preprocessing_steps: {
          training: {
            method: :categorical,
            params: {
              categorical_min: 3,
              one_hot: true,
            },
          },
        },
      )

      @dataset.refresh
      # Only 'a' appears 3 or more times
      expect(@dataset.data.columns).to include("group_a", "group_other")
      expect(@dataset.data.columns).not_to include("group_b", "group_c")
    end
  end

  describe "edge cases" do
    let(:float_col) { "points" }

    it "preprocesses constant with different type" do
      constant_value = "42"
      @dataset.columns.find_by(name: float_col).update(
        preprocessing_steps: {
          training: {
            method: :constant,
            params: {
              constant: constant_value,
            },
          },
        },
      )

      expect(@dataset.data[float_col].dtype).to eq Polars::Float64
      @dataset.refresh
      null_mask = @dataset.raw.read(:all)[float_col].is_null
      expect(@dataset.data[null_mask][float_col].to_a).to all(eq 42)
      expect(@dataset.data[float_col].dtype).to eq Polars::Float64
    end

    it "preprocesses constant with different type (bool -> string)" do
      @df_with_bool = @df.with_column(
        Polars.lit([true, false, true, false, nil, true, false, true, nil, nil]).alias("bool_col")
      )
      @datasource.update(df: @df_with_bool)
      @dataset.refresh
      @dataset.columns.find_by(name: "bool_col").update(
        preprocessing_steps: {
          training: {
            method: :constant,
            params: {
              constant: "true",
            },
          },
        },
      )

      expect(@dataset.data["bool_col"].dtype).to eq Polars::Boolean
      @dataset.refresh
      null_mask = @dataset.raw.read(:all)["bool_col"].is_null
      expect(@dataset.data[null_mask]["bool_col"].to_a).to all(eq true)
      expect(@dataset.data["bool_col"].dtype).to eq Polars::Boolean
    end

    it "allows change of constant value" do
      constant_value = "42"
      @dataset.columns.find_by(name: float_col).update(
        preprocessing_steps: {
          training: {
            method: :constant,
            params: {
              constant: constant_value,
            },
          },
        },
      )

      expect(@dataset.data[float_col].dtype).to eq Polars::Float64
      @dataset.refresh
      null_mask = @dataset.raw.read(:all)[float_col].is_null
      expect(@dataset.data[null_mask][float_col].to_a).to all(eq 42)
      expect(@dataset.data[float_col].dtype).to eq Polars::Float64

      constant_value = 100
      @dataset.columns.find_by(name: float_col).update(
        preprocessing_steps: {
          training: {
            method: :constant,
            params: {
              constant: constant_value,
            },
          },
        },
      )

      @dataset.refresh
      expect(@dataset.data[null_mask][float_col].to_a).to all(eq 100)
    end

    it "allows different strategy for inference" do
      @dataset.columns.find_by(name: "created_date").update(
        preprocessing_steps: {
          training: {
            method: :ffill,
          },
          inference: {
            method: :today,
          },
        },
      )

      @dataset.refresh

      statistics_last_val = @dataset.statistics.dig("raw", "created_date", "last_value")
      last_train_val = @dataset.train.sort("created_date")["created_date"][-1]
      raw_dataset = @dataset.raw.read(:all)
      null_mask = raw_dataset["created_date"].is_null
      expect(UTC.parse(statistics_last_val)).to eq last_train_val
      expect(@dataset.data[null_mask]["created_date"].to_a).to all(eq last_train_val)
      expect(@dataset.data[null_mask].count).to eq 2

      inference_df = Polars::DataFrame.new({
                                             id: [1],
                                             annual_revenue: [1000],
                                             group: ["a"],
                                             points: [1.0],
                                             created_date: [nil],
                                           })
      normalized = @dataset.normalize(inference_df, inference: true)
      expect(normalized["created_date"].to_a).to all(eq UTC.today.beginning_of_day)
    end
  end
end
