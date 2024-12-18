require "spec_helper"
require "support/model_spec_helper"
require "support/file_spec_helper"

RSpec.describe EasyML::Datasource do
  include ModelSpecHelper
  include FileSpecHelper

  after(:each) do
    EasyML::Cleaner.clean
  end

  describe "Polars Datasource" do
    let(:df) do
      df = Polars::DataFrame.new({
                                   id: [1, 2, 3, 4, 5, 6, 7, 8],
                                   rev: [0, 0, 100, 200, 0, 300, 400, 500],
                                   annual_revenue: [300, 400, 5000, 10_000, 20_000, 30, nil, nil],
                                   points: [1.0, 2.0, 0.1, 0.8, nil, 0.1, 0.4, 0.9],
                                   created_date: %w[2021-01-01 2021-01-01 2022-02-02 2024-01-01 2024-06-15 2024-07-01
                                                    2024-08-01 2024-09-01],
                                 })

      # Convert the 'created_date' column to datetime
      df.with_column(
        Polars.col("created_date").str.strptime(Polars::Datetime, "%Y-%m-%d").alias("created_date")
      )
    end

    it "creates polars datasources" do
      # Save the serialized DataFrame to the database
      datasource = EasyML::Datasource.create!(
        name: "My Polars Df",
        datasource_type: "polars",
        df: df,
      )
      datasource = EasyML::Datasource.find(datasource.id)
      expect(datasource.data).to eq df
    end

    it "creates histories" do
      datasource = EasyML::Datasource.create!(
        name: "My Polars Df",
        datasource_type: "polars",
        df: df,
      )
      datasource = EasyML::Datasource.find(datasource.id)
      datasource.snapshot
      snapshot = datasource.latest_snapshot

      expect(snapshot.data).to eq df
    end
  end

  describe "S3 Datasource" do
    it "saves and loads the s3 datasource" do
      file_spec do |_, csv_file, _|
        EasyML::Configuration.configure do |config|
          config.s3_access_key_id = "12345"
        end

        mock_s3_download(single_file_dir)
        s3_datasource = EasyML::Datasource.create!(
          name: "s3 Datasource",
          datasource_type: "s3",
          s3_bucket: "bucket",
          s3_prefix: "raw",
        )

        datasource = EasyML::Datasource.find(s3_datasource.id)
        expect(datasource.s3_bucket).to eq "bucket"

        correct_file = Polars.read_csv(csv_file)
        correct_file = EasyML::Data::DateConverter.maybe_convert_date(correct_file, "created_date")
        correct_file = correct_file.with_columns(
          Polars.col("loan_purpose").cast(Polars::Categorical),
          Polars.col("state").cast(Polars::Categorical)
        )
        datasource.clean
        datasource.refresh!

        expect(datasource.data).to eq(correct_file)
        expect(datasource.s3_access_key_id).to eq "12345"
        expect(datasource.configuration.keys).to include "s3_bucket"
        expect(datasource.configuration.keys).to_not include "s3_access_key_id"
        expect(datasource.configuration.keys).to_not include "s3_secret_access_key"
      end
    end

    it "refreshes synchronously" do
      mock_s3_download(multi_file_dir)
      s3_datasource = EasyML::Datasource.create!(
        name: "Multi File",
        datasource_type: "s3",
        s3_bucket: "bucket",
      )
      allow(Rails.env).to receive(:test?).and_return(false)
      s3_datasource.clean
      expect(Dir.glob(multi_file_dir.join("*.csv")).count).to eq 2
      expect(Dir.glob(multi_file_dir.join("*.parquet")).count).to eq 0
      expect(s3_datasource.data.count).to eq 16
      allow(Rails.env).to receive(:test?).and_return(true)

      s3_datasource.refresh
      expect(Dir.glob(multi_file_dir.join("*.csv")).count).to eq 2
      expect(Dir.glob(multi_file_dir.join("*.parquet")).count).to eq 2
      expect(s3_datasource.data.count).to eq 16
    end

    it "refreshes asynchronously" do
      mock_s3_download(multi_file_dir)
      s3_datasource = EasyML::Datasource.create!(
        name: "Multi File",
        datasource_type: "s3",
        s3_bucket: "bucket",
      )
      allow(Rails.env).to receive(:test?).and_return(false)
      s3_datasource.clean
      expect(Dir.glob(multi_file_dir.join("*.csv")).count).to eq 2
      expect(Dir.glob(multi_file_dir.join("*.parquet")).count).to eq 0
      allow(Rails.env).to receive(:test?).and_return(true)

      expect { s3_datasource.refresh_async }.to have_enqueued_job(EasyML::SyncDatasourceJob)
      perform_enqueued_jobs
      expect(Dir.glob(multi_file_dir.join("*.csv")).count).to eq 2
      expect(Dir.glob(multi_file_dir.join("*.parquet")).count).to eq 2
      expect(s3_datasource.data.count).to eq 16
    end
  end

  describe "File Datasource" do
    it "saves and loads the file datasource" do
      file_spec do |root_dir, _csv_file, parquet_file|
        polars_args = {
          dtypes: {
            'id': "i64",
            'business_name': "str",
            'annual_revenue': "f64",
            'rev': "f64",
            'created_date': "datetime",
          },
        }

        file_datasource = EasyML::Datasource.create!(
          name: "Single File",
          datasource_type: "file",
          polars_args: polars_args,
        )

        # Invoking this splits the file
        file_datasource.data

        df = Polars.read_parquet(parquet_file)

        datasource = EasyML::Datasource.find(file_datasource.id)
        expect(datasource.root_dir).to eq root_dir.to_s
        expect(datasource.data).to eq df
      end
    end
  end
end
