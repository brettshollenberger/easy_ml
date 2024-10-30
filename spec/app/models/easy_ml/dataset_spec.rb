require "spec_helper"
require "support/model_spec_helper"
require "support/file_spec_helper"

RSpec.describe EasyML::Datasource do
  include FileSpecHelper

  let(:dir) do
    SPEC_ROOT.join("lib/easy_ml/data/dataset/data/files/raw")
  end
  before(:each) do
    dataset.cleanup
  end

  after(:each) do
    dataset.cleanup
  end

  let(:dataset) do
    EasyML::Dataset.create(
      root_dir: dir,
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
        splitter_type: :date,
        today: EST.parse("2024-10-01"),
        date_col: "created_date",
        months_test: 2,
        months_valid: 2
      }
    )
  end

  describe "File datasource" do
    let(:datasource) do
      EasyML::Datasource.create(
        name: "Local dir",
        datasource_type: :file,
        root_dir: dir
      )
    end

    it "saves and reloads the dataset" do
      dataset.refresh!
      reloaded = EasyML::Dataset.find(dataset.id)
      expect(reloaded.datasource).to eq datasource
      expect(reloaded.datasource.data).to eq datasource.data
      expect(reloaded.datasource.data["loan_purpose"].to_a.first).to eq "payroll"
      expect(reloaded.target).to eq "rev"
      expect(reloaded.splitter.today).to eq dataset.splitter.today
      expect(reloaded.splitter.date_col).to eq dataset.splitter.date_col
      expect(reloaded.splitter.months_test).to eq dataset.splitter.months_test
      expect(reloaded.splitter.months_valid).to eq dataset.splitter.months_valid
      expect(reloaded.splitter).to be_a(EasyML::Data::Dataset::Splitters::DateSplitter)

      # The original dataset was processed, so the reloaded one is
      expect(reloaded).to be_processed
      expect(reloaded.train).to be_a(Polars::DataFrame)
    end

    it "sets up the dataset with correct attributes", :focus do
      file_spec do |_, _csv_file, _parquet_file|
        dataset.cleanup
        dataset.refresh!

        expect(dataset.datasource.root_dir).to eq dir.join("data").to_s
        x_train, = dataset.train(split_ys: true)
        x_valid, = dataset.valid(split_ys: true)
        x_test, = dataset.test(split_ys: true)

        expect(x_train.count).to eq 4
        expect(x_valid.count).to eq 2
        expect(x_test.count).to eq 2

        expect(dataset.raw).to be_a(EasyML::Data::Dataset::Splits::FileSplit)
        expect(dataset.processed).to be_a(EasyML::Data::Dataset::Splits::FileSplit)

        # Median applied
        expect(x_test["annual_revenue"].to_a).to all(eq(2_700))
        dataset.cleanup
      end
    end
  end

  describe "Polars datasource" do
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
        name: "dataset",
        datasource_type: :polars,
        df: df
      )
    end

    it "saves and reloads the dataset" do
      dataset.refresh!
      reloaded = EasyML::Dataset.find(dataset.id)
      expect(reloaded.datasource).to eq datasource
      expect(reloaded.datasource.data).to eq datasource.data
      expect(reloaded.target).to eq "rev"
      expect(reloaded.splitter.today).to eq dataset.splitter.today
      expect(reloaded.splitter.date_col).to eq dataset.splitter.date_col
      expect(reloaded.splitter.months_test).to eq dataset.splitter.months_test
      expect(reloaded.splitter.months_valid).to eq dataset.splitter.months_valid
      expect(reloaded.splitter).to be_a(EasyML::Data::Dataset::Splitters::DateSplitter)

      # It isn't processed, given that it's an in-memory datasource
      expect(reloaded).to_not be_processed
      expect(reloaded.train).to be_nil
      reloaded.refresh!
      expect(reloaded).to be_processed
      expect(reloaded.train).to be_a(Polars::DataFrame)
    end

    it "sets up the dataset with correct attributes" do
      dataset.refresh!
      x_train, = dataset.train(split_ys: true)
      x_test, = dataset.test(split_ys: true)
      x_valid, = dataset.valid(split_ys: true)

      expect(x_train.count).to eq 4
      expect(x_valid.count).to eq 2
      expect(x_test.count).to eq 2

      expect(dataset.raw).to be_a(EasyML::Data::Dataset::Splits::InMemorySplit)
      expect(dataset.processed).to be_a(EasyML::Data::Dataset::Splits::InMemorySplit)

      # Median applied
      expect(x_test["annual_revenue"].to_a).to all(eq(2_700))
      dataset.save
    end
  end
end
