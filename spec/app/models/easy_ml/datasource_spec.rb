require "spec_helper"
require "support/model_spec_helper"
require "support/file_spec_helper"

RSpec.describe EasyML::Datasource do
  include FileSpecHelper

  describe "Polars Datasource" do
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

    it "creates polars datasources" do
      # Save the serialized DataFrame to the database
      datasource = EasyML::Datasource.create!(
        name: "My Polars Df",
        datasource_type: :polars,
        df: df
      )

      datasource = EasyML::Datasource.find(datasource.id)
      expect(datasource.data).to eq df
    end
  end

  describe "S3 Datasource" do
    it "saves and loads the s3 datasource" do
      path = SPEC_ROOT.join("lib/easy_ml/data/dataset/data/files")
      file_spec do |_, csv_file, _|
        synced_directory = EasyML::Data::SyncedDirectory
        s3_datasource = EasyML::S3Datasource

        allow_any_instance_of(synced_directory).to receive(:synced?).and_return(false)
        allow_any_instance_of(synced_directory).to receive(:sync).and_return(true)
        allow_any_instance_of(synced_directory).to receive(:clean_dir!).and_return(true)
        allow_any_instance_of(s3_datasource).to receive(:refresh!).and_return(true)

        EasyML::Configuration.configure do |config|
          config.s3_access_key_id = "12345"
        end

        s3_datasource = EasyML::Datasource.create!(
          name: "s3 Datasource",
          datasource_type: :s3,
          root_dir: path,
          s3_bucket: "bucket",
          s3_prefix: "raw"
        )

        datasource = EasyML::Datasource.find(s3_datasource.id)
        expect(datasource.s3_bucket).to eq "bucket"
        expect(datasource.data).to eq(Polars.read_csv(csv_file))
        expect(datasource.s3_access_key_id).to eq "12345"
        expect(datasource.configuration.keys).to include "s3_bucket"
        expect(datasource.configuration.keys).to_not include "s3_access_key_id"
        expect(datasource.configuration.keys).to_not include "s3_secret_access_key"
      end
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
            'created_date': "datetime"
          }
        }

        file_datasource = EasyML::Datasource.create!(
          name: "File Datasource",
          datasource_type: :file,
          root_dir: root_dir,
          polars_args: polars_args
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
