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

  let(:datasource) do
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

  let(:synced_directory) do
    EasyML::Data::SyncedDirectory
  end

  describe "Features" do
    class BaseFeature
      include EasyML::Features
    end

    describe "base methods" do
      let(:feature) { BaseFeature.new }

      it "raises NotImplementedError for fit if not overridden" do
        expect { feature.fit(nil, nil) }.to raise_error(NotImplementedError)
      end

      it "raises NotImplementedError for batch if not overridden" do
        expect { feature.batch(nil, nil) }.to raise_error(NotImplementedError)
      end

      it "raises NotImplementedError for transform if not overridden" do
        expect { feature.transform(nil, nil) }.to raise_error(NotImplementedError)
      end
    end

    class DidConvert
      include EasyML::Features

      def transform(df, feature)
        df.with_column(
          (Polars.col("rev") > 0).alias("did_convert")
        )
      end

      feature name: "did_convert",
              description: "Boolean true/false, did the loan application fund?"
    end

    # class Age
    #   include EasyML::Features

    #   def age(df)
    #     df.with_column(
    #       Polars::Series.new("age", Array.new(df.height) { rand(1..50) })
    #     )
    #   end

    #   feature :age,
    #           name: "age",
    #           description: "Age of the owner"
    # end

    # class BusinessInception
    #   include EasyML::Features

    #   def business_inception(df)
    #     df.with_column(
    #       Polars::Series.new("business_inception", Array.new(df.height) do
    #         rand(Date.new(1970, 1, 1)..Date.today - 30.years)
    #       end).alias("business_inception")
    #     )
    #   end

    #   feature :business_inception,
    #           name: "Business Inception",
    #           description: "Business inception date"
    # end

    # class DaysInBusiness
    #   include EasyML::Features

    #   def days_in_business(df)
    #     df.with_column(
    #       (Polars.col("created_date") - Polars.col("business_inception")).dt.days.alias("days_in_business")
    #     )
    #   end

    #   feature :days_in_business,
    #           name: "Days in business",
    #           description: "Days since the business inception date"
    # end

    class BadFeature
      include EasyML::Features

      def transform(df, feature)
        "not a dataframe" # Intentionally return wrong type
      end

      feature name: "Bad Feature",
              description: "A feature that doesn't return a DataFrame"
    end

    before do
      EasyML::Features::Registry.register(DidConvert)
      # EasyML::Features::Registry.register(Age)
      # EasyML::Features::Registry.register(BusinessInception)
      # EasyML::Features::Registry.register(DaysInBusiness)
    end

    it "versions features" do
      # Create business_inception first since days_in_business depends on it
      expect(dataset).to be_needs_refresh
      dataset.refresh!
      expect(dataset).to_not be_needs_refresh

      # EasyML::Feature.new(
      #   dataset: dataset,
      #   feature_class: BusinessInception,
      #   feature_method: :business_inception,
      # ).insert

      # EasyML::Feature.new(
      #   dataset: dataset,
      #   feature_class: DaysInBusiness,
      #   feature_method: :days_in_business,
      # ).insert

      # # Insert age between business_inception and days_in_business
      # EasyML::Feature.new(
      #   dataset: dataset,
      #   feature_class: Age,
      #   feature_method: :age,
      # ).insert_after(:business_inception)

      # Prepend did_convert to be first
      EasyML::Feature.new(
        dataset: dataset,
        feature_class: DidConvert,
      ).prepend

      expect(dataset).to be_needs_refresh
      dataset.refresh!
      expect(dataset).to_not be_needs_refresh

      # Verify the data is computed correctly
      expect(dataset.data["did_convert"].to_a).to eq([false, false, true, true, false, true, true, true])
      expect(dataset.features.find_by(name: "Did Convert").version).to eq(1)

      dataset.bump_versions(dataset.version)
      expect(dataset.features.find_by(name: "Did Convert").version).to eq(2)
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

    describe "#fit method" do
      class LastAppTime
        include EasyML::Features

        # The job of fit is to pre-compute large set of values from entire datasource
        def fit(reader, feature)
          # Reader is the wrapper, which automatically queries the training data ONLY
          df = reader.read(:all, select: ["COMPANY_ID", "LOAN_APP_ID", "CREATED_AT"])
          batch_df = df.with_columns(
            Polars.col("CREATED_AT").shift(1).over("COMPANY_ID").alias("LAST_APP_TIME")
          )
          batch_df = batch_df[["COMPANY_ID", "LOAN_APP_ID", "LAST_APP_TIME"]]
          # EasyML::FeatureStore.store("loans.last_app_time", feature.version, batch_df)
        end

        def transform(df, feature)
          stored_df = EasyML::FeatureStore.load("loans.last_app_time", feature.version)
          df.join(stored_df, on: "LOAN_APP_ID", how: "left")
        end

        feature name: "Last Application Time",
                description: "Time since the company's last loan application"
      end

      let(:feature) do
        EasyML::Feature.create!(
          dataset: dataset,
          feature_class: "LastAppTime",
          name: "Last Application Time",
        )
      end

      let(:test_data) do
        [
          { "COMPANY_ID" => 1, "LOAN_APP_ID" => "A1", "CREATED_AT" => "2024-01-01" },
          { "COMPANY_ID" => 1, "LOAN_APP_ID" => "A2", "CREATED_AT" => "2024-01-02" },
          { "COMPANY_ID" => 2, "LOAN_APP_ID" => "B1", "CREATED_AT" => "2024-01-01" },
          { "COMPANY_ID" => 2, "LOAN_APP_ID" => "B2", "CREATED_AT" => "2024-01-03" },
        ]
      end

      before(:each) do
        # Register the feature
        EasyML::Features::Registry.register(LastAppTime)

        # Create test data in the training split
        df = Polars::DataFrame.new(test_data)
        dataset.raw.save(:train, df)
      end

      it "computes and stores feature values during fit", :focus do
        feature_instance = LastAppTime.new
        feature_instance.fit(dataset.raw, feature)

        # Load the stored feature values
        # stored_df = EasyML::FeatureStore.load("loans.last_app_time", feature.version)

        # # Verify the computed last application times
        # expect(stored_df.schema).to include(
        #   "COMPANY_ID" => Polars::Int64,
        #   "LOAN_APP_ID" => Polars::String,
        #   "LAST_APP_TIME" => Polars::String,
        # )

        # # Company 1's second application should have the first application time
        # second_app = stored_df.filter(Polars.col("LOAN_APP_ID").eq("A2")).select("LAST_APP_TIME").to_a.flatten.first
        # expect(second_app).to eq("2024-01-01")

        # # Company 2's second application should have the first application time
        # second_app = stored_df.filter(Polars.col("LOAN_APP_ID").eq("B2")).select("LAST_APP_TIME").to_a.flatten.first
        # expect(second_app).to eq("2024-01-01")
      end

      it "applies stored features during transform" do
        feature_instance = LastAppTime.new
        feature_instance.fit(dataset.split, feature)

        # Create a test dataframe for transformation
        test_df = Polars.from_records([
          { "LOAN_APP_ID" => "A2", "OTHER_COL" => "value" },
        ])

        # Transform the test data
        result_df = feature_instance.transform(test_df, feature)

        # Verify the transformation results
        expect(result_df.schema).to include(
          "LOAN_APP_ID" => Polars::String,
          "OTHER_COL" => Polars::String,
          "LAST_APP_TIME" => Polars::String,
        )

        last_app_time = result_df.select("LAST_APP_TIME").to_a.flatten.first
        expect(last_app_time).to eq("2024-01-01")
      end
    end

    describe "#batch_size" do
      class TestFeature
        include EasyML::Features
        feature name: "Test Feature",
               description: "A test feature",
               batch_size: 5000
      end

      class DefaultBatchFeature
        include EasyML::Features
        feature name: "Default Batch Feature",
               description: "A feature with default batch size"
      end

      before(:each) do
        EasyML::Features::Registry.register(TestFeature)
        EasyML::Features::Registry.register(DefaultBatchFeature)
      end

      after(:each) do
        EasyML::Features::Registry.instance_variable_set(:@registry, {})
      end

      it "returns configured batch size from feature class" do
        feature = EasyML::Feature.create!(
          dataset: dataset,
          feature_class: "TestFeature",
          name: "Test Feature"
        )
        expect(feature.batch_size).to eq(5000)
      end

      it "returns default batch size when not configured" do
        feature = EasyML::Feature.create!(
          dataset: dataset,
          feature_class: "DefaultBatchFeature",
          name: "Default Batch Feature"
        )
        expect(feature.batch_size).to eq(10_000)
      end
    end

    describe "#batch_size_changed?" do
      let(:feature) do
        EasyML::Feature.create!(
          dataset: dataset,
          feature_class: "TestFeature",
          name: "Test Feature"
        )
      end

      it "detects batch size changes" do
        allow(feature).to receive(:previous_changes).and_return(batch_size: [5000, 10_000])
        expect(feature.batch_size_changed?).to be true
      end

      it "ignores when batch size hasn't changed" do
        allow(feature).to receive(:previous_changes).and_return({})
        expect(feature.batch_size_changed?).to be false
      end
    end

    describe "code signature versioning" do
      let(:feature) do
        EasyML::Feature.create!(
          dataset: dataset,
          feature_class: "FeatureV1",
          name: "Test Feature V1",
        )
      end

      before(:each) do
        # Clear the registry and SHA cache before each test
        EasyML::Features::Registry.instance_variable_set(:@registry, {})
        EasyML::Feature.clear_sha_cache!

        # Load V1 of the feature
        load File.join(Rails.root, "fixtures/feature_v1.rb")
        feature.save! # This will compute and store the SHA for V1
      end

      after(:each) do
        # Clear the registry and SHA cache after each test
        EasyML::Features::Registry.instance_variable_set(:@registry, {})
        EasyML::Feature.clear_sha_cache!
      end

      describe "SHA caching" do
        let(:feature_path) { File.join(Rails.root, "fixtures/feature_v1.rb") }

        it "caches SHA computations" do
          # First computation should cache the SHA
          initial_sha = EasyML::Feature.compute_sha("FeatureV1")

          # Subsequent computations should use the cache
          expect(File).not_to receive(:read)
          expect(EasyML::Feature.compute_sha("FeatureV1")).to eq(initial_sha)
        end

        it "invalidates cache when file changes" do
          # Get initial SHA
          initial_sha = EasyML::Feature.compute_sha("FeatureV1")

          # Update file mtime
          FileUtils.touch(feature_path)

          # Should recompute SHA
          expect(File).to receive(:read).and_call_original
          EasyML::Feature.compute_sha("FeatureV1")
        end
      end

      context "when feature code hasn't changed" do
        it "is not returned in has_changes scope" do
          expect(EasyML::Feature.has_changes).not_to include(feature)
        end
      end

      context "when feature code has changed" do
        before do
          # Load V2 of the feature
          load File.join(Rails.root, "fixtures/feature_v2.rb")
        end

        it "is returned in has_changes scope" do
          expect(EasyML::Feature.has_changes).to include(feature)
        end
      end

      context "when feature has never been applied" do
        let(:unapplied_feature) do
          EasyML::Feature.create!(
            dataset: dataset,
            feature_class: "FeatureV1",
            name: "Unapplied Feature",
          )
        end

        it "is returned in needs_recompute scope" do
          expect(EasyML::Feature.needs_recompute).to include(unapplied_feature)
        end
      end

      context "when feature has been applied" do
        before do
          feature.update!(applied_at: Time.current)
        end

        it "is not returned in needs_recompute scope if code hasn't changed" do
          expect(EasyML::Feature.needs_recompute).not_to include(feature)
        end

        it "is returned in needs_recompute scope if code has changed" do
          load File.join(Rails.root, "fixtures/feature_v2.rb")
          expect(EasyML::Feature.needs_recompute).to include(feature)
        end
      end
    end
  end
end
