require "spec_helper"
require "support/model_spec_helper"
require "support/file_spec_helper"

RSpec.describe EasyML::Datasource do
  include ModelSpecHelper

  let(:today) do
    EasyML::Support::EST.parse("2024-10-01")
  end

  before(:each) do
    EasyML::Cleaner.clean
  end

  after(:each) do
    EasyML::Cleaner.clean
  end

  let(:dir) do
    single_file_dir
  end

  let(:s3_datasource) do
    EasyML::Datasource.create(
      name: "Single File",
      datasource_type: "s3",
      s3_bucket: "abc",
      s3_prefix: nil,
    )
  end

  let(:file_datasource) do
    EasyML::Datasource.create(
      name: "Single File",
      datasource_type: "file",
      root_dir: dir,
    )
  end

  let(:dataset) do
    EasyML::Dataset.create(
      name: "My Dataset",
      datasource: datasource,
      splitter_attributes: {
        splitter_type: "date",
        today: today,
        date_col: "created_date",
        months_test: 2,
        months_valid: 2,
      },
    )
  end

  let(:df) do
    df = Polars::DataFrame.new({
                                 id: [1, 2, 3, 4, 5, 6, 7, 8],
                                 rev: [0, 0, 100, 200, 0, 300, 400, 500],
                                 annual_revenue: [300, 400, 5000, 10_000, 20_000, 30, nil, nil],
                                 points: [1.0, 2.0, 0.1, 0.8, nil, 0.1, 0.4, 0.9],
                                 created_date: %w[2021-01-01 2021-01-01 2022-02-02 2024-01-01 2024-07-15 2024-08-01
                                                  2024-09-01 2024-10-01],
                               })

    # Convert the 'created_date' column to datetime
    df.with_column(
      Polars.col("created_date").str.strptime(Polars::Datetime, "%Y-%m-%d").alias("created_date")
    )
  end
  let(:polars_datasource) do
    EasyML::Datasource.create(
      name: "dataset",
      datasource_type: "polars",
      df: df,
    )
  end

  let(:synced_directory) do
    EasyML::Data::SyncedDirectory
  end

  describe "File datasource" do
    let(:datasource) { file_datasource }

    it "saves and reloads the dataset" do
      # Although this is a local datasource, we backup all datasets to S3
      mock_s3_download(single_file_dir)
      mock_s3_upload

      dataset.refresh!
      expect(dataset).to be_processed

      # When updating column, dataset is marked again as needing processing
      dataset.columns.find_by(name: "rev").update(is_target: true)
      expect(dataset).to_not be_processed
      dataset.refresh
      expect(dataset).to be_processed

      reloaded = EasyML::Dataset.find(dataset.id)
      expect(reloaded.datasource).to eq datasource
      expect(reloaded.datasource.data).to eq datasource.data
      expect(reloaded.datasource.data["loan_purpose"].to_a.first).to eq "payroll"
      expect(reloaded.target).to eq "rev"
      expect(reloaded.splitter.today).to eq dataset.splitter.today
      expect(reloaded.splitter.date_col).to eq dataset.splitter.date_col
      expect(reloaded.splitter.months_test).to eq dataset.splitter.months_test
      expect(reloaded.splitter.months_valid).to eq dataset.splitter.months_valid
      expect(reloaded.splitter.send(:adapter)).to be_a(EasyML::Splitters::DateSplitter)

      expect(reloaded.train).to be_a(Polars::DataFrame)
    end
  end

  describe "Polars datasource" do
    let(:datasource) { polars_datasource }

    it "saves and reloads the dataset" do
      dataset.refresh!
      dataset.columns.find_by(name: "rev").update(is_target: true)

      reloaded = EasyML::Dataset.find(dataset.id)
      expect(reloaded.datasource).to eq datasource
      expect(reloaded.datasource.data).to eq datasource.data
      expect(reloaded.target).to eq "rev"
      expect(reloaded.splitter.today).to eq dataset.splitter.today
      expect(reloaded.splitter.date_col).to eq dataset.splitter.date_col
      expect(reloaded.splitter.months_test).to eq dataset.splitter.months_test
      expect(reloaded.splitter.months_valid).to eq dataset.splitter.months_valid
      expect(reloaded.splitter.send(:adapter)).to be_a(EasyML::Splitters::DateSplitter)

      expect(reloaded).to_not be_processed
      expect(reloaded.train).to be_nil
      reloaded.refresh!
      expect(reloaded).to be_processed
      expect(reloaded.train).to be_a(Polars::DataFrame)
    end
  end

  describe "Features" do
    let(:datasource) { single_file_datasource }

    class DidConvert
      include EasyML::Features

      def transform(df)
        df.with_column(
          (Polars.col("rev") > 0).alias("did_convert")
        )
      end

      feature name: "did_convert",
              description: "Boolean true/false, did the loan application fund?"
    end

    class Age
      include EasyML::Features

      def transform(df)
        df.with_column(
          Polars::Series.new("age", Array.new(df.height) { rand(1..50) })
        )
      end

      feature name: "age",
              description: "Age of the owner"
    end

    class BusinessInception
      include EasyML::Features

      def transform(df)
        df.with_column(
          Polars::Series.new("business_inception", Array.new(df.height) do
            rand(Date.new(1970, 1, 1)..Date.today - 30.years)
          end).alias("business_inception")
        )
      end

      feature name: "Business Inception",
              description: "Business inception date"
    end

    class DaysInBusiness
      include EasyML::Features

      def transform(df)
        df.with_column(
          (Polars.col("created_date") - Polars.col("business_inception")).dt.days.alias("days_in_business")
        )
      end

      feature name: "Days in business",
              description: "Days since the business inception date"
    end

    class BadFeature
      include EasyML::Features

      def transform(_df)
        "not a dataframe" # Intentionally return wrong type
      end

      feature name: "Bad Feature",
              description: "A feature that doesn't return a DataFrame"
    end

    before do
      EasyML::Features::Registry.register(DidConvert)
      EasyML::Features::Registry.register(Age)
      EasyML::Features::Registry.register(BusinessInception)
      EasyML::Features::Registry.register(DaysInBusiness)
    end

    it "creates computed columns in the correct order" do
      # Create business_inception first since days_in_business depends on it
      expect(dataset).to be_needs_refresh
      dataset.refresh!
      expect(dataset).to_not be_needs_refresh

      EasyML::Feature.new(
        dataset: dataset,
        feature_class: BusinessInception,
      ).insert

      EasyML::Feature.new(
        dataset: dataset,
        feature_class: DaysInBusiness,
      ).insert

      # Insert age between business_inception and days_in_business
      EasyML::Feature.new(
        dataset: dataset,
        feature_class: Age,
      ).insert_after(:business_inception)

      # Prepend did_convert to be first
      EasyML::Feature.new(
        dataset: dataset,
        feature_class: DidConvert,
      ).prepend

      expect(dataset).to be_needs_refresh
      dataset.refresh!
      expect(dataset).to_not be_needs_refresh

      features = dataset.features.ordered
      expect(features.map(&:name)).to eq(
        %w[did_convert business_inception age days_in_business]
      )

      # Verify the data is computed correctly
      expect(dataset.data["did_convert"].to_a).to eq([
                                                       false, false, true, true, false, true, true, true,
                                                     ])
      expect(dataset.statistics.dig("raw", "age", "mean")).to be_between(1, 50)
      expect(dataset.data["days_in_business"].to_a).to all(be > 0)
    end

    it "raises appropriate error if any feature doesn't return df" do
      # Register the bad feature
      EasyML::Features::Registry.register(BadFeature)

      # Create a feature that will fail
      feature = EasyML::Feature.new(
        dataset: dataset,
        feature_class: BadFeature,
      )
      feature.insert

      # Attempt to refresh the dataset
      expect do
        dataset.refresh!
      end.to raise_error(/Feature 'bad_feature' must return a Polars::DataFrame/)
    end
  end

  describe "Refreshing Dataset" do
    describe "S3 Datasource" do
      let(:datasource) { s3_datasource }

      it "refreshes synchronously" do
        mock_s3_download(multi_file_dir)
        mock_s3_upload

        dataset.refresh
        expect(dataset.data.count).to eq 16
      end

      it "refreshes asynchronously" do
        mock_s3_download(multi_file_dir)
        mock_s3_upload

        expect { dataset }.to have_enqueued_job(EasyML::RefreshDatasetJob)
        perform_enqueued_jobs
        expect(dataset.data.count).to eq 16
      end
    end

    describe "Polars datasource" do
      let(:datasource) { polars_datasource }

      it "returns true when never refreshed (refreshed_at is nil)" do
        expect(dataset.refreshed_at).to be_nil
        expect(dataset).to be_needs_refresh
      end

      context "when previously refreshed" do
        before do
          dataset.refresh!
        end

        it "returns true when columns have been updated" do
          # Travel forward in time to make the update
          Timecop.travel 1.minute do
            dataset.columns.find_by(name: "rev").update!(is_target: true)
          end

          expect(dataset).to be_needs_refresh
        end

        it "returns true when features have been updated" do
          Timecop.travel 1.minute do
            EasyML::Feature.create!(
              dataset: dataset,
              feature_class: Age,
            )
          end

          expect(dataset).to be_needs_refresh
        end

        it "returns true when datasource needs refresh" do
          allow(dataset.datasource).to receive(:needs_refresh?).and_return(true)
          expect(dataset).to be_needs_refresh
        end

        it "returns false when nothing has changed" do
          expect(dataset).not_to be_needs_refresh
        end
      end
    end
  end

  describe "Splitting files" do
    let(:datasource) { s3_datasource }
    let(:synced_directory) do
      EasyML::Data::SyncedDirectory
    end

    it "splits files" do
      mock_s3_download(single_file_dir)
      mock_s3_upload

      dataset.refresh!
      expect(dataset.train.count).to eq 6
      expect(dataset.test.count).to eq 1
      expect(dataset.valid.count).to eq 1
      expect(dataset.data.count).to eq 8 # Entire dataset
    end

    it "splits targets" do
      mock_s3_download(single_file_dir)
      mock_s3_upload

      dataset.refresh!
      dataset.columns.find_by(name: "rev").update(is_target: true)
      dataset.refresh!
      _, ys = dataset.train(split_ys: true)
      expect(ys["rev"]).to eq dataset.train["rev"]
    end
  end

  describe "Splitting files" do
    let(:datasource) { s3_datasource }

    it "splits files" do
      mock_s3_download(single_file_dir)
      mock_s3_upload

      dataset.refresh!
      expect(dataset.train.count).to eq 6
      expect(dataset.test.count).to eq 1
      expect(dataset.valid.count).to eq 1
      expect(dataset.data.count).to eq 8 # Entire dataset
    end

    it "splits targets" do
      mock_s3_download(single_file_dir)
      mock_s3_upload

      dataset.refresh!
      dataset.columns.find_by(name: "rev").update(is_target: true)
      dataset.refresh!
      _, ys = dataset.train(split_ys: true)
      expect(ys["rev"]).to eq dataset.train["rev"]
    end
  end

  describe "Column configuration" do
    let(:datasource) { s3_datasource }

    it "drops columns" do
      mock_s3_download(single_file_dir)
      mock_s3_upload

      dataset.refresh!
      expect(dataset.train.columns).to include("drop_me")

      dataset.columns.find_by(name: "drop_me").update(hidden: true)
      dataset.refresh!
      expect(dataset.train.columns).to_not include("drop_me")

      expect(dataset.train(all_columns: true).columns).to include("drop_me")
    end

    it "drops rows" do
      mock_s3_download(single_file_dir)
      mock_s3_upload

      dataset.refresh!
      expect(dataset.data.count).to eq 8
      expect(dataset.data[dataset.data["annual_revenue"].is_null].count).to eq 2

      dataset.columns.find_by(name: "annual_revenue").update(drop_if_null: true)
      dataset.refresh!
      expect(dataset.data.count).to eq 6
      expect(dataset.data[dataset.data["annual_revenue"].is_null].count).to eq 0
    end
  end
end
