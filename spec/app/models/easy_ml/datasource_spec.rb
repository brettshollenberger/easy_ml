require "spec_helper"
require "support/model_spec_helper"
require "support/file_spec_helper"

RSpec.describe EasyML::Datasource do
  include ModelSpecHelper
  include FileSpecHelper

  after(:each) do
    EasyML::Cleaner.clean
  end

  describe "S3 Datasource" do
    it "saves and loads the s3 datasource" do
      EasyML::Configuration.configure do |config|
        config.s3_access_key_id = "12345"
      end

      mock_s3_download(s3_dir(single_file_dir, ".csv"))
      s3_datasource = EasyML::Datasource.create!(
        name: "s3 Datasource",
        datasource_type: "s3",
        s3_bucket: "bucket",
        s3_prefix: "raw",
      )

      datasource = EasyML::Datasource.find(s3_datasource.id)
      expect(datasource.s3_bucket).to eq "bucket"

      file = Dir.glob(File.join(s3_dir(single_file_dir, ".csv"), "**/*.csv")).first
      correct_file = Polars.read_csv(file)
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

    it "refreshes synchronously" do
      mock_s3_download(s3_dir(multi_file_dir, ".csv"))

      s3_datasource = EasyML::Datasource.create!(
        name: "Multi File",
        datasource_type: "s3",
        s3_bucket: "bucket",
      )

      # Actually allow cleaning
      allow(Rails.env).to receive(:test?).and_return(false)
      s3_datasource.clean
      expect(Dir.glob(multi_file_dir.join("*.csv")).count).to eq 0
      expect(Dir.glob(multi_file_dir.join("*.parquet")).count).to eq 0
      expect(s3_datasource.data.count).to eq 0
      allow(Rails.env).to receive(:test?).and_return(true)

      # Then re-download from "remote"
      s3_datasource.refresh
      expect(Dir.glob(multi_file_dir.join("*.csv")).count).to eq 2
      expect(Dir.glob(multi_file_dir.join("*.parquet")).count).to eq 2
      expect(s3_datasource.data.count).to eq 16
    end

    it "automatically sets schema, raw schema, and column dtypes" do
      mock_s3_download(s3_dir(multi_file_dir, ".csv"))

      s3_datasource = EasyML::Datasource.create!(
        name: "Multi File",
        datasource_type: "s3",
        s3_bucket: "bucket",
      )
      s3_dataset = EasyML::Dataset.create(
        name: "My Dataset",
        datasource: s3_datasource,
        splitter_attributes: {
          splitter_type: "random",
          seed: 42,
        },
      )

      expect(s3_dataset.columns).to be_empty
      s3_dataset.refresh

      expect(s3_dataset.columns).not_to be_empty

      columns = [{ :name => "annual_revenue", :datatype => "integer" },
                 { :name => "created_date", :datatype => "datetime" },
                 { :name => "drop_me", :datatype => "boolean" },
                 { :name => "id", :datatype => "integer" },
                 { :name => "rev", :datatype => "integer" },
                 { :name => "loan_purpose", :datatype => "categorical" },
                 { :name => "state", :datatype => "categorical" }]

      columns.each do |col|
        column = s3_dataset.columns.find_by(name: col[:name])
        expect(column).to be_present
        expect(column.datatype.to_sym).to eq(col[:datatype].to_sym)
        expect(column).to be_in_raw_dataset
      end

      expect(s3_dataset.schema).to match(hash_including(
        {
          id: Polars::Int64,
          rev: Polars::Int64,
          annual_revenue: Polars::Int64,
          created_date: Polars::Datetime,
          drop_me: Polars::Boolean,
          loan_purpose: Polars::Categorical,
          state: Polars::Categorical,
        }
      ))
    end

    it "refreshes asynchronously" do
      mock_s3_download(s3_dir(multi_file_dir, ".csv"))
      s3_datasource = EasyML::Datasource.create!(
        name: "Multi File",
        datasource_type: "s3",
        s3_bucket: "bucket",
      )
      allow(Rails.env).to receive(:test?).and_return(false)
      s3_datasource.clean
      expect(Dir.glob(multi_file_dir.join("*.csv")).count).to eq 0
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
