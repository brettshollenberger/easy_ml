require "spec_helper"
require "support/model_spec_helper"
require "support/file_spec_helper"

RSpec.describe EasyML::FeatureStore do
  include ModelSpecHelper

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

  before(:each) do
    feature.wipe
    simple_feature.wipe
  end

  after(:each) do
    feature.wipe
    simple_feature.wipe
  end

  let(:test_data) do
    [
      { "LOAN_APP_ID" => 5, "LAST_APP_TIME" => "2024-01-01" },
      { "LOAN_APP_ID" => 15, "LAST_APP_TIME" => "2024-01-02" },
    ]
  end

  let(:df) { Polars::DataFrame.new(test_data) }

  describe ".store" do
    context "with partitioning" do
      let(:expected_paths) do
        [
          File.join(
            dataset.dir,
            "features",
            feature.name.parameterize.gsub(/-/, "_"),
            "1",
            "feature.1.parquet"
          ),
          File.join(
            dataset.dir,
            "features",
            feature.name.parameterize.gsub(/-/, "_"),
            "2",
            "feature.1.parquet"
          ),
        ]
      end

      it "writes data to correct partition files" do
        feature.wipe
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
    end

    context "without partitioning" do
      let(:simple_data) do
        [
          { "COMPANY_ID" => 1, "SIMPLE_TIME" => "2024-01-01" },
          { "COMPANY_ID" => 2, "SIMPLE_TIME" => "2024-01-02" },
          { "COMPANY_ID" => 3, "SIMPLE_TIME" => "2024-01-01" },
          { "COMPANY_ID" => 4, "SIMPLE_TIME" => "2024-01-01" },
          { "COMPANY_ID" => 5, "SIMPLE_TIME" => "2024-01-01" },
          { "COMPANY_ID" => 6, "SIMPLE_TIME" => "2024-01-01" },
          { "COMPANY_ID" => 7, "SIMPLE_TIME" => "2024-01-01" },
          { "COMPANY_ID" => 8, "SIMPLE_TIME" => "2024-01-02" },
          { "COMPANY_ID" => 9, "SIMPLE_TIME" => "2024-01-02" },
          { "COMPANY_ID" => 10, "SIMPLE_TIME" => "2024-01-02" },
        ]
      end

      let(:simple_df) { Polars::DataFrame.new(simple_data) }

      let(:expected_path) do
        File.join(
          dataset.dir,
          "features",
          simple_feature.name.parameterize.gsub(/-/, "_"),
          "compacted.parquet"
        )
      end

      it "writes dataframe to single file" do
        simple_feature.wipe
        simple_feature.store(simple_df)
        simple_feature.compact
        expect(simple_feature.files).to include(expected_path)
        expect(File.exist?(expected_path)).to be true
        stored_df = Polars.read_parquet(expected_path)
        expect(stored_df.to_hashes).to match_array(simple_data)
        expect(simple_feature.query.to_hashes).to match_array(simple_data)
      end

      it "does not completely bork the file when computed in batches" do
        simple_feature.wipe

        simple_df_batch_one = simple_df[0..5]
        simple_df_batch_two = simple_df[6..10]
        simple_feature.store(simple_df_batch_one)
        simple_feature.store(simple_df_batch_two)
        simple_feature.compact

        expect(File.exist?(expected_path)).to be true
        stored_df = Polars.read_parquet(expected_path)
        expect(stored_df.to_hashes).to match_array(simple_data)
        expect(simple_feature.query.to_hashes).to match_array(simple_data)
      end
    end
  end

  describe ".query" do
    context "with primary key filter" do
      before do
        feature.wipe
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
        simple_feature.wipe
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
