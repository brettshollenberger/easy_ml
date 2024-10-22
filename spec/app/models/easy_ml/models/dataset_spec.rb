require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::Datasource do
  let(:df) do
    df = Polars::DataFrame.new({
                                 id: [1, 2, 3, 4, 5, 6, 7, 8],
                                 rev: [0, 0, 100, 200, 0, 300, 400, 500],
                                 annual_revenue: [300, 400, 5000, 10_000, 20_000, 30, nil, nil],
                                 points: [1.0, 2.0, 0.1, 0.8, nil, 0.1, 0.4, 0.9],
                                 created_date: %w[2021-01-01 2021-01-01 2022-02-02 2024-01-01 2024-06-15 2024-07-01
                                                  2024-08-01 2024-09-01]
                               })

    # Convert the 'created_date' column to datetime
    df.with_column(
      Polars.col("created_date").str.strptime(Polars::Datetime, "%Y-%m-%d").alias("created_date")
    )
  end

  let(:datasource) do
    EasyML::Datasource.create(
      name: "polars",
      df: df
    )
  end

  let(:dataset) do
    EasyML::Dataset.create(
      target: "rev",
      name: "My Dataset",
      datasource: datasource,
      preprocessing_steps: {
        training: {
          annual_revenue: {
            median: true
          }
        }
      },
      splitter: {
        date: {
          today: EST.parse("2024-10-01"),
          date_col: "created_date",
          months_test: 2,
          months_valid: 2
        }
      }
    )
  end

  it "saves and reloads the dataset" do
    dataset
    reloaded = EasyML::Dataset.find(dataset.id)
    expect(reloaded.datasource).to eq datasource
    expect(reloaded.datasource.df).to eq datasource.df
    expect(reloaded.target).to eq "rev"
    expect(reloaded.splitter.today).to eq dataset.splitter.today
    expect(reloaded.splitter.date_col).to eq dataset.splitter.date_col
    expect(reloaded.splitter.months_test).to eq dataset.splitter.months_test
    expect(reloaded.splitter.months_valid).to eq dataset.splitter.months_valid
    expect(reloaded.splitter).to be_a(EasyML::Data::Dataset::Splitters::DateSplitter)
  end
end
