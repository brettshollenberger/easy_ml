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

      it "raises NotImplementedError for transform if not overridden" do
        expect { feature.transform(nil, nil) }.to raise_error(NotImplementedError)
      end
    end

    class DidConvert
      include EasyML::Features

      def fit(df, feature)
        df.with_column(
          (Polars.col("rev") > 0).alias("did_convert")
        )
      end

      def transform(df, feature)
      end

      feature name: "did_convert",
              description: "Boolean true/false, did the loan application fund?",
              primary_key: "LOAN_APP_ID"
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

        def fit(df, feature)
          batch_df = df.with_columns(
            Polars.col("CREATED_AT").shift(1).over("COMPANY_ID").alias("LAST_APP_TIME")
          )
          batch_df[["COMPANY_ID", "LOAN_APP_ID", "LAST_APP_TIME"]]
        end

        def transform(df, feature)
          stored_df = EasyML::FeatureStore.query(feature, filter: Polars.col("LOAN_APP_ID").is_in(df["LOAN_APP_ID"]))
          df.join(stored_df, on: "LOAN_APP_ID", how: "left")
        end

        feature name: "Last Application Time",
                description: "Time since the company's last loan application",
                primary_key: "LOAN_APP_ID",
                batch_size: 10,
                needs_columns: ["LOAN_APP_ID", "CREATED_AT", "COMPANY_ID"]
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

      it "computes and stores feature values during fit" do
        fit_df = feature.fit(dataset.raw)

        # Load the stored feature values
        stored_df = EasyML::FeatureStore.query(feature)

        expect(stored_df).to eq(fit_df)

        # # Verify the computed last application times
        expect(stored_df.schema).to include(
          "COMPANY_ID" => Polars::Int64,
          "LOAN_APP_ID" => Polars::String,
          "LAST_APP_TIME" => Polars::String,
        )

        # # Company 1's second application should have the first application time
        second_app = stored_df.filter(Polars.col("LOAN_APP_ID").eq("A2")).select("LAST_APP_TIME").to_a.flatten.first["LAST_APP_TIME"]
        expect(second_app).to eq("2024-01-01")

        # # Company 2's second application should have the first application time
        second_app = stored_df.filter(Polars.col("LOAN_APP_ID").eq("B2")).select("LAST_APP_TIME").to_a.flatten.first["LAST_APP_TIME"]
        expect(second_app).to eq("2024-01-01")
      end

      it "applies stored features during transform" do
        feature.fit(dataset.raw)

        # Create a test dataframe for transformation
        test_df = Polars::DataFrame.new([
          { "LOAN_APP_ID" => "A2", "OTHER_COL" => "value" },
        ])

        # Transform the test data
        result_df = feature.transform(test_df)

        # Verify the transformation results
        expect(result_df.schema).to include(
          "LOAN_APP_ID" => Polars::String,
          "OTHER_COL" => Polars::String,
          "LAST_APP_TIME" => Polars::String,
        )

        last_app_time = result_df.select("LAST_APP_TIME").to_a.flatten.first["LAST_APP_TIME"]
        expect(last_app_time).to eq("2024-01-01")
      end

      describe "#fit" do
        let(:test_data) do
          [
            { "COMPANY_ID" => 1, "CREATED_AT" => "2024-01-01" },
            { "COMPANY_ID" => 2, "CREATED_AT" => "2024-01-02" },
          ]
        end

        let(:reader) { instance_double("EasyML::Data::Reader") }
        let(:feature_instance) { instance_double("LastAppTime") }
        let(:batch_df) { Polars::DataFrame.new(test_data) }

        before do
          allow(LastAppTime).to receive(:new).and_return(feature_instance)
          allow(feature_instance).to receive(:fit).and_return(batch_df)
          allow(reader).to receive(:read).and_return(batch_df)
          allow(EasyML::FeatureStore).to receive(:store)
        end

        it "computes features using the feature class" do
          feature.fit(reader)
          expect(feature_instance).to have_received(:fit).with(reader, feature)
        end

        it "stores the computed features" do
          feature.fit(reader)
          expect(EasyML::FeatureStore).to have_received(:store).with(feature, batch_df)
        end

        it "updates applied_at timestamp" do
          expect { feature.fit(reader) }.to change { feature.applied_at }.from(nil)
        end

        it "returns the computed batch dataframe" do
          expect(feature.fit(reader)).to eq(batch_df)
        end
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
          name: "Test Feature",
        )
        expect(feature.batch_size).to eq(5000)
      end

      it "returns default batch size when not configured" do
        feature = EasyML::Feature.create!(
          dataset: dataset,
          feature_class: "DefaultBatchFeature",
          name: "Default Batch Feature",
        )
        expect(feature.batch_size).to eq(10_000)
      end
    end

    describe "batch processing" do
      class BatchFeature
        include EasyML::Features

        def fit(reader, feature)
          df = batch_df || reader.read(:all)
          df.with_columns(
            Polars.col("CREATED_AT").shift(1).over("COMPANY_ID").alias("LAST_APP_TIME")
          )
        end

        def transform(df, feature)
          stored_df = EasyML::FeatureStore.query(feature, filter: Polars.col("COMPANY_ID").is_in(df["COMPANY_ID"]))
          df.join(stored_df, on: "COMPANY_ID", how: "left")
        end

        feature name: "Batch Feature",
                description: "A feature that processes in batches",
                batch_size: 10,
                primary_key: "COMPANY_ID"
      end

      let(:feature) do
        EasyML::Feature.create!(
          dataset: dataset,
          feature_class: "BatchFeature",
          name: "Batch Feature",
          batch_size: 10,
        )
      end

      let(:test_data) do
        (1..100).map do |company_id|
          {
            "COMPANY_ID" => company_id,
            "CREATED_AT" => "2024-01-#{company_id.to_s.rjust(2, "0")}",
          }
        end
      end

      let(:df) { Polars::DataFrame.new(test_data) }
      let(:reader) { instance_double("EasyML::Data::PolarsReader") }

      before do
        EasyML::Features::Registry.register(BatchFeature)
        allow(reader).to receive(:query).and_return(df)
      end

      describe "#batch" do
        context "when feature needs recompute" do
          before do
            allow(feature).to receive(:needs_recompute?).and_return(true)
            allow(feature).to receive(:reset)
          end

          it "resets the feature" do
            feature.batch(reader)
            expect(feature).to have_received(:reset)
          end
        end

        it "computes the feature in batches", :focus do
          binding.pry
        end

        it "splits data into batches based on batch_size" do
          feature.batch(reader)
          expect(batch).to have_received(:add).exactly(10).times
        end

        it "passes correct batch boundaries to jobs" do
          feature.batch(reader)

          # Check first batch
          expect(batch).to have_received(:add).with(
            EasyML::Jobs::ComputeFeatureBatchJob,
            [feature.id, 1, 10] # feature_id, min_id, max_id
          ).ordered

          # Check last batch
          expect(batch).to have_received(:add).with(
            EasyML::Jobs::ComputeFeatureBatchJob,
            [feature.id, 91, 100] # feature_id, min_id, max_id
          ).ordered
        end

        it "sets up finalization callback" do
          feature.batch(reader)
          expect(batch).to have_received(:on_complete).with(
            EasyML::Jobs::FinalizeFeatureJob,
            [feature.id]
          )
        end
      end

      describe "end-to-end batch processing" do
        let(:feature_instance) { BatchFeature.new }

        before do
          allow(BatchFeature).to receive(:new).and_return(feature_instance)
          allow(feature_instance).to receive(:fit).and_call_original
          allow(EasyML::FeatureStore).to receive(:store)

          # Simulate batch job execution
          allow(batch).to receive(:add) do |job_class, args|
            feature_id, min_id, max_id = args

            # Get batch data
            batch_df = df.filter(
              (Polars.col("COMPANY_ID").ge(min_id)) &
              (Polars.col("COMPANY_ID").lt(max_id))
            )

            # Process batch
            result_df = feature_instance.fit(reader, feature, batch_df)
            EasyML::FeatureStore.store(feature, result_df)
          end

          # Simulate finalization
          allow(batch).to receive(:on_complete) do |job_class, args|
            feature.update!(
              applied_at: Time.current,
              needs_recompute: false,
            )
          end

          feature.batch(reader)
        end

        it "processes each batch with the feature adapter" do
          expect(feature_instance).to have_received(:fit).exactly(10).times
        end

        it "stores results for each batch" do
          expect(EasyML::FeatureStore).to have_received(:store).exactly(10).times
        end

        it "updates feature status after completion" do
          expect(feature.applied_at).to be_present
          expect(feature.needs_recompute).to be false
        end

        it "allows querying across batch boundaries" do
          test_df = Polars::DataFrame.new([
            { "COMPANY_ID" => 5 },   # First batch
            { "COMPANY_ID" => 55 },  # Middle batch
            { "COMPANY_ID" => 95 },  # Last batch
          ])

          allow(EasyML::FeatureStore).to receive(:query).and_return(df)
          result = feature.transform(test_df)
          expect(result["LAST_APP_TIME"].to_a).to all(be_present)
        end
      end
    end

    describe "code signature versioning" do
      let(:feature) do
        EasyML::Feature.create!(
          dataset: dataset,
          feature_class: "FeatureV1",
          name: "Test Feature V1",
          batch_size: 10,
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

      context "when feature has different batch_size than its code" do
        it "is returned in needs_recompute scope" do
          feature.update(batch_size: 100)
          expect(EasyML::Feature.needs_recompute).to include(feature)
        end

        it "resets after running fit" do
          feature.update(batch_size: 100)
          expect(EasyML::Feature.needs_recompute).to include(feature)

          feature.fit(dataset.raw)
          expect(EasyML::Feature.needs_recompute).to_not include(feature)
        end
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
