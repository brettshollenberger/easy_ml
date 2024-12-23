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
      feature.store(batch_df)
    end

    def transform(df, feature)
      stored_df = feature.query
      df.join(stored_df, on: "LOAN_APP_ID", how: "left")
    end

    feature name: "Last Application Time",
            description: "Time since the company's last loan application",
            batch_size: 10,
            primary_key: "LOAN_APP_ID"
  end

  class SimpleFeature
    include EasyML::Features

    def fit(reader, feature)
      df = reader.read(:all, select: ["COMPANY_ID", "CREATED_AT"])
      batch_df = df.with_columns(
        Polars.col("CREATED_AT").alias("SIMPLE_TIME")
      )
      batch_df = batch_df[["COMPANY_ID", "SIMPLE_TIME"]]
      feature.store(batch_df)
    end

    def transform(df, feature)
      stored_df = feature.query
      df.join(stored_df, on: "COMPANY_ID", how: "left")
    end

    feature name: "Simple Time",
            description: "Simple non-partitioned feature",
            batch_size: 10
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

  let(:simple_feature) do
    EasyML::Feature.create!(
      dataset: dataset,
      feature_class: "SimpleFeature",
      name: "Simple Feature",
      version: 1,
    )
  end

  let(:test_data) do
    [
      { "LOAN_APP_ID" => 5, "LAST_APP_TIME" => "2024-01-01" },
      { "LOAN_APP_ID" => 15, "LAST_APP_TIME" => "2024-01-02" },
    ]
  end

  let(:df) { Polars::DataFrame.new(test_data) }

  before(:each) do
    EasyML::Features::Registry.register(LastAppTime)
    EasyML::Features::Registry.register(SimpleFeature)
  end

  after(:each) do
    EasyML::Features::Registry.instance_variable_set(:@registry, {})
    FileUtils.rm_rf(File.join(Rails.root, "easy_ml"))
  end

  describe ".store" do
    context "with partitioning" do
      let(:expected_paths) do
        [
          File.join(
            Rails.root,
            "easy_ml/datasets",
            dataset.name.parameterize,
            "features",
            feature.name.parameterize,
            feature.version.to_s,
            "feature0.parquet"
          ),
          File.join(
            Rails.root,
            "easy_ml/datasets",
            dataset.name.parameterize,
            "features",
            feature.name.parameterize,
            feature.version.to_s,
            "feature10.parquet"
          ),
        ]
      end

      it "writes data to correct partition files" do
        feature.store(df)

        # Check first partition (0-9)
        first_partition = Polars.read_parquet(expected_paths[0])
        expect(first_partition.to_hashes).to contain_exactly(
          { "LOAN_APP_ID" => 5, "LAST_APP_TIME" => "2024-01-01" }
        )

        # Check second partition (10-19)
        second_partition = Polars.read_parquet(expected_paths[1])
        expect(second_partition.to_hashes).to contain_exactly(
          { "LOAN_APP_ID" => 15, "LAST_APP_TIME" => "2024-01-02" }
        )
      end

      context "when updating existing partitions" do
        let(:existing_data) do
          [
            { "LOAN_APP_ID" => 5, "LAST_APP_TIME" => "2024-01-31" },  # Will be overwritten
            { "LOAN_APP_ID" => 7, "LAST_APP_TIME" => "2024-01-03" },  # Will be preserved
          ]
        end

        before do
          existing_df = Polars::DataFrame.new(existing_data)
          feature.store(existing_df)
        end

        it "updates only affected partitions" do
          new_data = [
            { "LOAN_APP_ID" => 5, "LAST_APP_TIME" => "2024-01-04" },  # Updates existing record
          ]
          new_df = Polars::DataFrame.new(new_data)

          feature.store(new_df)

          # Check first partition (0-9)
          first_partition = Polars.read_parquet(expected_paths[0])
          expect(first_partition.sort("LOAN_APP_ID").to_hashes).to contain_exactly(
            { "LOAN_APP_ID" => 5, "LAST_APP_TIME" => "2024-01-04" },
            { "LOAN_APP_ID" => 7, "LAST_APP_TIME" => "2024-01-03" }
          )
        end
      end
    end

    context "without partitioning" do
      let(:simple_data) do
        [
          { "COMPANY_ID" => 1, "SIMPLE_TIME" => "2024-01-01" },
          { "COMPANY_ID" => 2, "SIMPLE_TIME" => "2024-01-02" },
        ]
      end

      let(:simple_df) { Polars::DataFrame.new(simple_data) }

      let(:expected_path) do
        File.join(
          Rails.root,
          "easy_ml/datasets",
          dataset.name.parameterize,
          "features",
          simple_feature.name.parameterize,
          simple_feature.version.to_s,
          "feature.parquet"
        )
      end

      it "writes dataframe to single file" do
        simple_feature.store(simple_df)
        expect(File.exist?(expected_path)).to be true
        stored_df = Polars.read_parquet(expected_path)
        expect(stored_df.to_hashes).to match_array(simple_data)
      end
    end
  end

  describe ".query" do
    context "with primary key filter" do
      before do
        feature.store(df)
      end

      it "loads only relevant partitions" do
        result = feature.query(
          filter: Polars.col("LOAN_APP_ID").eq(5),
        )
        expect(result.to_hashes).to contain_exactly(
          { "LOAN_APP_ID" => 5, "LAST_APP_TIME" => "2024-01-01" }
        )
      end

      it "handles queries spanning multiple partitions" do
        result = feature.query(
          filter: (Polars.col("LOAN_APP_ID").gt(4) & Polars.col("LOAN_APP_ID").lt(16)),
        )
        expect(result.to_hashes).to match_array(test_data)
      end
    end

    context "without primary key" do
      let(:simple_data) do
        [
          { "COMPANY_ID" => 1, "SIMPLE_TIME" => "2024-01-01" },
          { "COMPANY_ID" => 2, "SIMPLE_TIME" => "2024-01-02" },
        ]
      end

      before do
        simple_df = Polars::DataFrame.new(simple_data)
        simple_feature.store(simple_df)
      end

      it "returns all data from single file" do
        result = simple_feature.query
        expect(result.to_hashes).to match_array(simple_data)
      end

      it "supports filtering on non-primary key columns" do
        result = simple_feature.query(
          filter: Polars.col("COMPANY_ID").eq(1),
        )
        expect(result.to_hashes).to contain_exactly(
          { "COMPANY_ID" => 1, "SIMPLE_TIME" => "2024-01-01" }
        )
      end
    end
  end
end
