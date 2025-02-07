require "spec_helper"
require "support/model_spec_helper"
require "support/file_spec_helper"

RSpec.describe EasyML::Dataset do
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
      dataset.reload
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

  describe "needs_refresh?" do
    let(:datasource) { single_file_datasource }

    context "Tracking last datasource sha" do
      it "tracks last datasource sha" do
        dataset.refresh
        expect(dataset.datasource.sha).to be_present
        expect(dataset.last_datasource_sha).to eq(dataset.datasource.sha)
      end
    end

    context "does column need learn?" do
      it "when column has never previously been learned" do
        dataset.prepare
        dataset.learn
        expect(EasyML::Column.needs_learn.count).to eq(EasyML::Column.count)
        expect(EasyML::Column.needs_learn.count).to be > 0
      end

      it "when column, feature, and sha have not changed" do
        dataset.refresh
        expect(EasyML::Column.datasource_changed).to be_empty
        expect(EasyML::Column.feature_applied).to be_empty
        expect(EasyML::Column.feature_changed).to be_empty
        expect(EasyML::Column.column_changed).to be_empty
        expect(EasyML::Column.needs_learn).to be_empty
      end

      it "when column changed, statistics are re-learned" do
        dataset.refresh
        column = dataset.columns.first
        column.update(is_target: true)

        expect(EasyML::Column.datasource_changed).to be_empty
        expect(EasyML::Column.feature_applied).to be_empty
        expect(EasyML::Column.feature_changed).to be_empty
        expect(EasyML::Column.column_changed.map(&:id)).to include(column.id)
        expect(EasyML::Column.needs_learn.map(&:id)).to include(column.id)

        dataset.columns.each do |col|
          expect(col.statistics).to have_key(:raw), "#{col.name} does not have raw statistics"
          expect(col.statistics).to have_key(:processed), "#{col.name} does not have processed statistics"
          expect(col.statistics).to have_key(:clipped), "#{col.name} does not have clipped statistics"
        end
      end

      def change_feature_definition
        load File.join(Rails.root, "fixtures/did_convert_v2.rb")
      end

      it "when feature added/changed, the new feature is learned" do
        original_time = UTC.now
        Timecop.freeze(original_time)
        dataset.refresh

        later_time = original_time + 3.days
        Timecop.freeze(later_time)
        dataset.features.create(
          feature_class: DidConvert,
        )
        dataset.refresh

        computed_features, non_computed_features = dataset.columns.partition(&:is_computed?)
        computed_features_learned_at = computed_features.map(&:learned_at).uniq.first
        non_computed_features_learned_at = non_computed_features.map(&:learned_at).uniq.first

        expect(non_computed_features_learned_at).to eq(original_time)
        expect(computed_features_learned_at).to eq(later_time)

        expect(EasyML::Column.datasource_changed).to be_empty
        expect(EasyML::Column.feature_applied).to be_empty
        expect(EasyML::Column.feature_changed).to be_empty
        expect(EasyML::Column.column_changed.map(&:id)).to be_empty
        expect(EasyML::Column.needs_learn.map(&:id)).to be_empty

        even_later_time = later_time + 3.days
        Timecop.freeze(even_later_time)

        expect(EasyML::Column.needs_learn).to be_empty
        change_feature_definition

        expect(EasyML::Column.needs_learn.map(&:id)).to include(computed_features.first.id)
        expect(EasyML::Column.needs_learn.count).to eq 1

        dataset.refresh
        expect(EasyML::Column.needs_learn).to be_empty

        computed_features, non_computed_features = dataset.columns.partition(&:is_computed?)
        computed_features_learned_at = computed_features.map(&:learned_at).uniq.first
        non_computed_features_learned_at = non_computed_features.map(&:learned_at).uniq.first

        expect(non_computed_features_learned_at).to eq(original_time)
        expect(computed_features_learned_at).to eq(even_later_time)

        Timecop.return
      end

      context "When underlying datasource changes, statistics are re-learned" do
        let(:day_1_dir) do
          titanic_core_dir
        end

        let(:day_2_dir) do
          titanic_extended_dir
        end

        let(:datasource) do
          EasyML::Datasource.create(
            name: "Titanic Core",
            datasource_type: "s3",
            s3_bucket: "titanic",
          )
        end

        let(:target) { "Survived" }
        let(:dataset_config) do
          {
            name: "Titanic Dataset",
            datasource: datasource,
            splitter_attributes: {
              splitter_type: "random",
            },
          }
        end
        let(:dataset) do
          titanic_core_dataset
        end

        let(:hidden_cols) do
          %w[Name Ticket Cabin]
        end

        let(:dataset) do
          mock_s3_download(day_1_dir)
          mock_s3_upload

          EasyML::Features::Registry.register(FamilySizeFeature)
          EasyML::Dataset.create(**dataset_config).tap do |dataset|
            family_size_feature = EasyML::Feature.create!(
              dataset: dataset,
              feature_class: FamilySizeFeature.to_s,
              name: "Family Size",
            )
            dataset.refresh
            dataset.columns.find_by(name: target).update(is_target: true)
            dataset.columns.where(name: hidden_cols).update_all(hidden: true)
            dataset.columns.find_by(name: "Sex").update(preprocessing_steps: {
                                                          training: {
                                                            method: :categorical,
                                                            params: {
                                                              one_hot: true,
                                                            },
                                                          },
                                                        })
            dataset.columns.find_by(name: "Embarked").update(preprocessing_steps: {
                                                               training: {
                                                                 method: :categorical,
                                                                 params: {
                                                                   one_hot: true,
                                                                 },
                                                               },
                                                             })
            dataset.columns.find_by(name: "Age").update(preprocessing_steps: {
                                                          training: {
                                                            method: :median,
                                                          },
                                                        })
            dataset.refresh
          end
        end

        it "needs refresh when underlying datasource changes" do
          original_time = UTC.now
          Timecop.freeze(original_time)
          dataset

          expect(dataset.columns.needs_learn).to be_empty

          later_time = original_time + 3.days
          Timecop.freeze(later_time)

          # By default, we read from the directory with the name provided,
          # so this will switch us to using a bigger dataset
          datasource.name = "Titanic Extended"
          datasource.save
          mock_s3_download(day_2_dir) # Download a DIFFERENT version of the dataset
          datasource.refresh!

          expect(dataset.columns.needs_learn.count).to eq dataset.columns.count
          dataset.refresh

          expect(dataset.columns.needs_learn).to be_empty

          Timecop.return
        end
      end
    end

    context "when dataset is not split" do
      it "needs refresh until split" do
        mock_s3_download(single_file_dir)
        expect(dataset).to be_needs_refresh
        expect(dataset.refresh_reasons).to include("Not split")

        dataset.refresh!
        expect(dataset).to_not be_needs_refresh
        expect(dataset.refresh_reasons).to be_empty
      end
    end

    context "when refreshed_at is nil" do
      it "needs refresh when refreshed_at is cleared" do
        mock_s3_download(single_file_dir)
        dataset.refresh!
        expect(dataset).to_not be_needs_refresh

        dataset.update_column(:refreshed_at, nil)
        dataset.reload
        expect(dataset).to be_needs_refresh
        expect(dataset.refresh_reasons).to include("Refreshed at is nil")

        dataset.refresh!
        expect(dataset).to_not be_needs_refresh
        expect(dataset.refresh_reasons).to be_empty
      end
    end

    context "when columns change" do
      it "needs refresh when columns are updated" do
        mock_s3_download(single_file_dir)
        dataset.refresh!
        expect(dataset).to_not be_needs_refresh

        dataset.columns.find_by(name: "rev").update(is_target: true)
        dataset.reload
        expect(dataset).to be_needs_refresh
        expect(dataset.refresh_reasons).to include("Columns need refresh")

        dataset.refresh!
        expect(dataset).to_not be_needs_refresh
        expect(dataset.refresh_reasons).to be_empty
      end
    end

    context "when features change" do
      before do
        EasyML::Features::Registry.register(DidConvert)
      end

      it "needs refresh when features are added" do
        mock_s3_download(single_file_dir)
        dataset.refresh!
        expect(dataset).to_not be_needs_refresh

        EasyML::Feature.new(
          dataset: dataset,
          feature_class: DidConvert,
        ).prepend

        dataset.reload
        expect(dataset).to be_needs_refresh
        expect(dataset.refresh_reasons).to include("Features need refresh")

        dataset.refresh!
        expect(dataset).to_not be_needs_refresh
        expect(dataset.refresh_reasons).to be_empty
      end
    end

    context "when datasource needs refresh" do
      it "needs refresh when datasource is marked for refresh" do
        mock_s3_download(single_file_dir)
        dataset.refresh!
        expect(dataset).to_not be_needs_refresh

        allow(dataset.datasource).to receive(:needs_refresh?).and_return(true)
        expect(dataset).to be_needs_refresh
        expect(dataset.refresh_reasons).to include("Datasource needs refresh")

        allow(dataset.datasource).to receive(:needs_refresh?).and_return(false)
        expect(dataset).to_not be_needs_refresh
        expect(dataset.refresh_reasons).to be_empty
      end
    end

    context "when datasource is refreshed" do
      it "needs refresh when datasource is updated" do
        mock_s3_download(single_file_dir)
        dataset.refresh!
        expect(dataset).to_not be_needs_refresh

        allow(dataset.datasource).to receive(:last_updated_at).and_return(Time.current)
        expect(dataset).to be_needs_refresh
        expect(dataset.refresh_reasons).to include("Datasource was refreshed")

        Timecop.freeze(2.hours.from_now)

        dataset.refresh!
        expect(dataset).to_not be_needs_refresh
        expect(dataset.refresh_reasons).to be_empty

        Timecop.return
      end
    end
  end

  describe "Features" do
    let(:datasource) { single_file_datasource }

    class DidConvert
      include EasyML::Features

      def computes_columns
        ["did_convert"]
      end

      def transform(df, feature)
        df.with_column(
          (Polars.col("rev") > 0).alias("did_convert")
        )
      end

      feature name: "did_convert",
              description: "Boolean true/false, did the loan application fund?"
    end

    class Age
      include EasyML::Features

      def computes_columns
        ["age"]
      end

      def transform(df, feature)
        df.with_column(
          Polars::Series.new("age", Array.new(df.height) { rand(1..50) })
        )
      end

      feature name: "age",
              description: "Age of the owner"
    end

    class BusinessInception
      include EasyML::Features

      def computes_columns
        ["business_inception"]
      end

      def transform(df, feature)
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

      def computes_columns
        ["days_in_business"]
      end

      def transform(df, feature)
        df.with_column(
          (Polars.col("created_date") - Polars.col("business_inception")).dt.days.alias("days_in_business")
        )
      end

      feature name: "Days in business",
              description: "Days since the business inception date"
    end

    class BadFeature
      include EasyML::Features

      def computes_columns
        ["bad_feature"]
      end

      def transform(_df, feature)
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
      ).insert_after(BusinessInception)

      # Prepend did_convert to be first
      EasyML::Feature.new(
        dataset: dataset,
        feature_class: DidConvert,
      ).prepend

      dataset.reload
      expect(dataset).to be_needs_refresh
      dataset.refresh!
      expect(dataset).to_not be_needs_refresh

      features = dataset.features.ordered
      expect(features.map(&:name)).to eq(
        [
          "Did Convert", "Business Inception", "Age", "Days In Business",
        ]
      )

      # Verify the data is computed correctly
      expect(dataset.data["did_convert"].to_a).to eq([
                                                       false, false, true, true, false, true, true, true,
                                                     ])
      expect(dataset.statistics.dig("processed", "age", "mean")).to be_between(1, 50)
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
      end.to raise_error(/Feature 'Bad Feature' must return a Polars::DataFrame/)
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

          expect(dataset.reload).to be_needs_refresh
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

  describe "hidden columns" do
    let(:dataset) do
      titanic_dataset
    end

    it "hides one-hot encoded virtual columns when original column is hidden" do
      # Create a categorical column with one-hot encoding
      column = dataset.columns.find_by(name: "Embarked")
      %w(C Q S).each do |value|
        expect(dataset.data.columns).to include("Embarked_#{value}")
      end
      column.update(hidden: true)

      # Load the data
      dataset.refresh
      %w(C Q S).each do |value|
        expect(dataset.data.columns).to_not include("Embarked_#{value}")
      end
    end
  end

  describe "Exporting/importing dataset from JSON" do
    let(:dataset) do
      titanic_dataset
    end

    before do
      dataset.features.create!(
        name: "FamilySize",
        feature_class: "FamilySizeFeature",
      )
      dataset.refresh
    end

    describe "#to_config" do
      it "exports the dataset configuration as JSON" do
        json_config = dataset.to_config

        expect(json_config["dataset"]["name"]).to eq("Titanic")
        expect(json_config["dataset"]["datasource"]["name"]).to eq("Titanic Extended")
        expect(json_config["dataset"]["datasource"]["datasource_type"]).to eq("file")

        column_config = json_config["dataset"]["columns"].first
        expect(column_config["name"]).to eq("PassengerId")
        expect(column_config["datatype"]).to eq("integer")

        feature_config = json_config["dataset"]["features"].first
        expect(feature_config["name"]).to eq("FamilySize")
        expect(feature_config["feature_class"]).to eq("FamilySizeFeature")
      end
    end

    describe ".from_json_config" do
      it "creates a new dataset from JSON configuration", :focus do
        @dataset = dataset
        @dataset.columns.find_by(name: "Age").update(
          preprocessing_steps: {
            training: {
              method: :median,
              params: {
                clip: { min: 0, max: 10 },
              },
            },
          },
        )
        json_config = @dataset.to_config

        @dataset.destroy! # Destroy existing dataset
        expect(EasyML::Column.count).to eq(0)

        dataset = EasyML::Dataset.from_config(json_config)

        expect(dataset).to be_persisted
        expect(dataset.name).to eq("Titanic")
        expect(dataset.datasource.name).to eq("Titanic Extended")
        expect(dataset.datasource.datasource_type).to eq("file")

        column = dataset.columns.find_by(name: "PassengerId")
        expect(column.name).to eq("PassengerId")
        expect(column.datatype).to eq("integer")

        feature = dataset.features.first
        expect(feature.name).to eq("FamilySize")
        expect(feature.feature_class).to eq("FamilySizeFeature")

        dataset.refresh
        expect(dataset.data.columns).to include("FamilySize")
        expect(dataset.data["Age"].max).to eq 10 # Preprocesing steps applied
      end
    end
  end
end
