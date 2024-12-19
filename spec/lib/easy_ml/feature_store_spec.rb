require "spec_helper"
require "support/model_spec_helper"
require "support/file_spec_helper"

RSpec.describe EasyML::FeatureStore do
  include ModelSpecHelper

  before(:all) do
    require_rails_files
  end

  class LastAppTime
    include EasyML::Features

    def fit(reader, feature)
      df = reader.read(:all, select: ["COMPANY_ID", "LOAN_APP_ID", "CREATED_AT"])
      batch_df = df.with_columns(
        Polars.col("CREATED_AT").shift(1).over("COMPANY_ID").alias("LAST_APP_TIME")
      )
      batch_df = batch_df[["COMPANY_ID", "LOAN_APP_ID", "LAST_APP_TIME"]]
      EasyML::FeatureStore.store(feature, batch_df, primary_key: "LOAN_APP_ID")
    end

    def transform(df, feature)
      stored_df = EasyML::FeatureStore.query(feature)
      df.join(stored_df, on: "LOAN_APP_ID", how: "left")
    end

    feature name: "Last Application Time",
            description: "Time since the company's last loan application"
  end

  let(:datasource) do
    EasyML::Datasource.create!(
      name: "Test Source",
      datasource_type: "file",
      root_dir: "/tmp/test_source",
    )
  end

  let(:dataset) do
    EasyML::Dataset.create!(
      name: "Test Dataset",
      datasource: datasource,
      splitter_attributes: {
        splitter_type: "date",
        today: Time.current,
        date_col: "created_date",
        months_test: 2,
        months_valid: 2,
      },
    )
  end

  let(:feature) do
    EasyML::Feature.create!(
      dataset: dataset,
      feature_class: "LastAppTime",
      name: "Last App Time",
      version: 1,
    )
  end

  let(:test_data) do
    [
      { "LOAN_APP_ID" => "A1", "LAST_APP_TIME" => "2024-01-01" },
      { "LOAN_APP_ID" => "A2", "LAST_APP_TIME" => "2024-01-02" },
    ]
  end

  let(:df) { Polars::DataFrame.new(test_data) }
  let(:feature_key) { "loans.last_app_time" }

  before(:each) do
    EasyML::Features::Registry.register(LastAppTime)
  end

  after(:each) do
    EasyML::Features::Registry.instance_variable_set(:@registry, {})
  end

  describe ".store" do
    let(:expected_path) do
      File.join(
        Rails.root,
        "easy_ml/datasets",
        dataset.name.parameterize,
        "features",
        feature.name.parameterize,
        feature.version.to_s,
        "feature.parquet"
      )
    end

    it "writes dataframe to the correct path" do
      EasyML::FeatureStore.store(feature, df)
      expect(File.exist?(expected_path)).to be true
    end

    context "when file already exists" do
      let(:existing_data) do
        [
          { "LOAN_APP_ID" => "A1", "LAST_APP_TIME" => "2023-12-31" },  # Will be overwritten
          { "LOAN_APP_ID" => "A3", "LAST_APP_TIME" => "2024-01-03" },  # Will be preserved
        ]
      end

      before do
        # Store existing data first
        existing_df = Polars::DataFrame.new(existing_data)
        EasyML::FeatureStore.store(feature, existing_df)
      end

      it "upserts data based on primary key" do
        EasyML::FeatureStore.store(feature, df, primary_key: "LOAN_APP_ID")

        # Read the stored data
        stored_df = Polars.read_parquet(expected_path)
        stored_records = stored_df.sort("LOAN_APP_ID").to_hashes

        # Should contain:
        # - A1 with updated time (from new data)
        # - A2 from new data
        # - A3 from existing data (preserved)
        expect(stored_records).to contain_exactly(
          { "LOAN_APP_ID" => "A1", "LAST_APP_TIME" => "2024-01-01" },
          { "LOAN_APP_ID" => "A2", "LAST_APP_TIME" => "2024-01-02" },
          { "LOAN_APP_ID" => "A3", "LAST_APP_TIME" => "2024-01-03" }
        )
      end
    end
  end

  describe ".query" do
    before do
      # Store test data
      EasyML::FeatureStore.store(feature, df)
    end

    it "returns all data when no filter is provided" do
      result = EasyML::FeatureStore.query(feature)
      expect(result.to_hashes).to match_array(test_data)
    end

    it "applies filter when provided" do
      result = EasyML::FeatureStore.query(
        feature,
        filter: Polars.col("LOAN_APP_ID").eq("A1"),
      )
      expect(result.to_hashes).to contain_exactly(
        { "LOAN_APP_ID" => "A1", "LAST_APP_TIME" => "2024-01-01" }
      )
    end
  end
end
