require "spec_helper"
require "support/model_spec_helper"
require "support/file_spec_helper"
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
# EasyML::Features::Registry.register(Age)
# EasyML::Features::Registry.register(BusinessInception)
# EasyML::Features::Registry.register(DaysInBusiness)
#
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

RSpec.describe EasyML::Datasource do
  include ModelSpecHelper

  let(:today) do
    EasyML::Support::EST.parse("2024-10-01")
  end

  before(:each) do
    EasyML::Cleaner.clean
    EasyML::Features::Registry.register(DidConvert)
    EasyML::Features::Registry.register(BadFeature)
    EasyML::Features::Registry.register(LastAppTime)
    EasyML::Features::Registry.register(TestFeature)
    EasyML::Features::Registry.register(DefaultBatchFeature)
    EasyML::Features::Registry.register(ZipFeature)
    EasyML::Features::Registry.register(BatchFeature)
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

  class ZipFeature
    include EasyML::Features

    def fit(df, feature, options = {})
      zip_df = EasyML::Dataset.find_by(name: "Zips").data

      # Join with zip data and return just the columns we need
      df.join(
        zip_df,
        on: "ZIP",
        how: "left",
      )[["ID", "CITY", "STATE", "POPULATION"]]
    end

    def transform(df, feature)
      binding.pry

      stored_df = EasyML::FeatureStore.query(feature, filter: Polars.col("ID").is_in(df["ID"]))
      return df if stored_df.empty?

      df.join(stored_df, on: "ID", how: "left")
    end

    feature name: "Zip Feature",
            description: "Adds ZIP code data based on ID",
            batch_size: 10,
            primary_key: "ID"
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

  class BadFeature
    include EasyML::Features

    def transform(df, feature)
      "not a dataframe" # Intentionally return wrong type
    end

    feature name: "Bad Feature",
            description: "A feature that doesn't return a DataFrame"
  end

  class BaseFeature
    include EasyML::Features
  end

  class LastAppTime
    include EasyML::Features

    def fit(df, feature, options = {})
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

  class BatchFeature
    include EasyML::Features

    def batch(reader, feature)
      reader.query(select: ["COMPANY_ID"], unique: true)["COMPANY_ID"]
    end

    def fit(reader, feature, options = {})
      batch_start = options.dig(:batch_start)
      batch_end = options.dig(:batch_end)

      df = reader.query(
        filter: Polars.col("COMPANY_ID").is_in((batch_start..batch_end).to_a),
        sort: ["COMPANY_ID", "ID"],
      )

      df.with_columns(
        Polars.col("CREATED_AT").shift(1).over("COMPANY_ID").alias("LAST_APP_TIME")
      )[["ID", "LAST_APP_TIME"]]
    end

    def transform(df, feature)
      stored_df = EasyML::FeatureStore.query(feature, filter: Polars.col("ID").is_in(df["ID"]))
      return df if stored_df.empty?

      df.join(stored_df, on: "ID", how: "left")
    end

    feature name: "Batch Feature",
            description: "A feature that processes in batches",
            batch_size: 10,
            primary_key: "ID"
  end

  let(:zips_datasource) do
    EasyML::Datasource.create(
      name: "Zips",
      datasource_type: "file",
    )
  end

  let(:zips_dataset) do
    zips = EasyML::Dataset.create(
      name: "Zips",
      datasource: zips_datasource,
      splitter_attributes: {
        splitter_type: "random",
      },
    )

    zips.refresh
    zips.columns.find_by(name: "ZIP").update(datatype: "string")
    zips.refresh
    zips
  end

  describe "Features" do
    describe "base methods" do
      let(:feature) { BaseFeature.new }

      it "raises NotImplementedError for transform if not overridden" do
        expect { feature.transform(nil, nil) }.to raise_error(NotImplementedError)
      end
    end
    before do
    end

    it "versions features" do
      # Create business_inception first since days_in_business depends on it
      expect(dataset).to be_needs_refresh
      dataset.refresh!
      expect(dataset).to_not be_needs_refresh

      # Prepend did_convert to be first
      EasyML::Feature.new(
        dataset: dataset,
        feature_class: DidConvert,
      ).prepend

      expect(dataset).to be_needs_refresh
      dataset.refresh

      # Verify the data is computed correctly
      expect(dataset.data["did_convert"].to_a).to eq([false, false, true, true, false, true, true, true])
      expect(dataset.features.find_by(name: "Did Convert").version).to eq(1)

      dataset.bump_versions(dataset.version)
      expect(dataset.features.find_by(name: "Did Convert").version).to eq(2)
    end

    it "raises appropriate error if any feature doesn't return df" do

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
        # Create test data in the training split
        df = Polars::DataFrame.new(test_data)
        dataset.raw.save(:train, df)
      end

      it "computes and stores feature values during fit" do
        fit_df = feature.fit

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
        feature.fit

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

        let(:feature_instance) { instance_double("LastAppTime") }
        let(:batch_df) { Polars::DataFrame.new(test_data) }

        before do
          allow(LastAppTime).to receive(:new).and_return(feature_instance)
          allow(feature_instance).to receive(:fit).and_return(batch_df)
          allow(EasyML::FeatureStore).to receive(:store)
        end

        it "computes features using the feature class" do
          feature.fit
          expect(feature_instance).to have_received(:fit).with(any_args)
        end

        it "stores the computed features" do
          feature.fit
          expect(EasyML::FeatureStore).to have_received(:store).with(any_args)
        end

        it "updates applied_at timestamp" do
          expect { feature.fit }.to change { feature.applied_at }.from(nil)
        end

        it "returns the computed batch dataframe" do
          expect(feature.fit).to eq(batch_df)
        end
      end
    end

    describe "#batch_size" do
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

      it "has no batch size when not set" do
        feature = EasyML::Feature.create!(
          dataset: dataset,
          feature_class: "DefaultBatchFeature",
          name: "Default Batch Feature",
        )
        expect(feature.batch_size).to be_nil
        expect(feature).to_not be_batchable
      end
    end

    describe "batch processing" do
      let(:datasource) do
        EasyML::Datasource.create(
          name: "Batches",
          datasource_type: "file",
        )
      end

      let(:dataset) do
        EasyML::Dataset.create(
          name: "My Dataset",
          datasource: datasource,
          splitter_attributes: {
            splitter_type: "random",
          },
        )
      end

      describe "default batching with primary key" do
        let(:feature) do
          EasyML::Feature.create!(
            dataset: dataset,
            feature_class: "ZipFeature",
            name: "Zip Feature",
          )
        end

        it "computes the feature in batches based on ID ranges" do
          zips_dataset
          feature
          dataset.refresh
          dataset.columns.find_by(name: "ZIP").update(datatype: "string")
          dataset.refresh
          clear_enqueued_jobs

          # Feature lazily creates the dataset, which triggers the refresh
          expect { dataset.refresh_async }.to have_enqueued_job(EasyML::RefreshDatasetJob).with(dataset.id)

          perform_enqueued_jobs
          expect(EasyML::ComputeFeaturesJob).to have_been_enqueued.with(dataset.id)

          perform_enqueued_jobs

          batch_jobs = Resque.peek(:easy_ml, 0, 10)
          expect(batch_jobs.length).to eq(10) # 10 jobs

          # Verify first batch
          first_job = batch_jobs.first
          expect(first_job["class"]).to eq("EasyML::ComputeFeatureJob")
          expect(first_job["args"].last[:batch_start]).to eq(1)
          expect(first_job["args"].last[:batch_end]).to eq(10)

          # Verify last batch
          last_job = batch_jobs.last
          expect(last_job["class"]).to eq("EasyML::ComputeFeatureJob")
          expect(last_job["args"].last[:batch_start]).to eq(91)
          expect(last_job["args"].last[:batch_end]).to eq(100)

          # Process all batch jobs
          batch_jobs.each do |job|
            Resque.reserve(:easy_ml).perform
          end

          # Test that the feature data was computed correctly
          affected_rows = dataset.data(filter: Polars.col("ID").is_between(1, 10), sort: "ID")

          # First row should have ZIP 00001 and match with first ZIP in our data
          first_row = affected_rows.filter(Polars.col("ID").eq(1))
          expect(first_row["CITY"].to_a.first).to eq("HOLTSVILLE")
          expect(first_row["STATE"].to_a.first).to eq("NY")
          expect(first_row["POPULATION"].to_a.first).to eq(1000)

          # Fifth row should have ZIP 00005 and match with BARRE
          fifth_row = affected_rows.filter(Polars.col("ID").eq(5))
          expect(fifth_row["CITY"].to_a.first).to eq("AMHERST")
          expect(fifth_row["STATE"].to_a.first).to eq("MA")
          expect(fifth_row["POPULATION"].to_a.first).to eq(20000)

          # Feature should be marked as computed
          feature.reload
          expect(feature.fit_at).to be_present
          expect(feature.needs_recompute).to be false

          dataset.reload
          expect(dataset.needs_refresh?).to be false
        end

        describe "#batch" do
          context "when feature needs recompute" do
            before do
              allow(feature).to receive(:needs_recompute?).and_return(true)
              allow(feature).to receive(:reset)
            end

            it "resets the feature" do
              feature.batch
              expect(feature).to have_received(:reset)
            end
          end
        end
      end

      describe "custom batching" do
        let(:feature) do
          EasyML::Feature.create!(
            dataset: dataset,
            feature_class: "BatchFeature",
            name: "Batch Feature",
            batch_size: 10,
          )
        end
        it "computes the feature in batches based on custom batch args" do
          # Feature lazily creates the dataset, which triggers the refresh
          expect { feature }.to have_enqueued_job(EasyML::RefreshDatasetJob)

          perform_enqueued_jobs
          expect(EasyML::ComputeFeaturesJob).to have_been_enqueued.with(dataset.id)

          perform_enqueued_jobs

          batch_jobs = Resque.peek(:easy_ml, 0, 10)
          expect(batch_jobs.length).to eq(10) # 10 jobs

          # Verify first batch
          first_job = batch_jobs.first
          expect(first_job["class"]).to eq("EasyML::ComputeFeatureJob")
          expect(first_job["args"].last[:batch_start]).to eq(1)
          expect(first_job["args"].last[:batch_end]).to eq(10)

          # Verify last batch
          last_job = batch_jobs.last
          expect(last_job["class"]).to eq("EasyML::ComputeFeatureJob")
          expect(last_job["args"].last[:batch_start]).to eq(91)
          expect(last_job["args"].last[:batch_end]).to eq(100)

          # Here we need to run the jobs queued via resque,
          # because we're using the resque batched gem, we
          # need to queue these outside of ActiveJob
          batch_jobs.each do |job|
            Resque.reserve(:easy_ml).perform
          end

          affected_rows = dataset.data(filter: Polars.col("COMPANY_ID").is_in([1, 2, 3, 4, 10, 12]), sort: ["COMPANY_ID", "ID"])

          # Test specific rows have expected LAST_APP_TIME values
          expect(affected_rows.filter(Polars.col("ID").eq(1))["LAST_APP_TIME"].to_a.first).to be_nil
          expect(affected_rows.filter(Polars.col("ID").eq(19))["LAST_APP_TIME"].to_a.first).to eq("2024-01-01")
          expect(affected_rows.filter(Polars.col("ID").eq(29))["LAST_APP_TIME"].to_a.first).to eq("2024-01-19")
          expect(affected_rows.filter(Polars.col("ID").eq(2))["LAST_APP_TIME"].to_a.first).to be_nil
          expect(affected_rows.filter(Polars.col("ID").eq(39))["LAST_APP_TIME"].to_a.first).to eq("2024-01-02")
          expect(affected_rows.filter(Polars.col("ID").eq(73))["LAST_APP_TIME"].to_a.first).to eq("2024-01-04")
          expect(affected_rows.filter(Polars.col("ID").eq(10))["LAST_APP_TIME"].to_a.first).to be_nil
          expect(affected_rows.filter(Polars.col("ID").eq(86))["LAST_APP_TIME"].to_a.first).to eq("2024-01-10")
          expect(affected_rows.filter(Polars.col("ID").eq(12))["LAST_APP_TIME"].to_a.first).to be_nil
          expect(affected_rows.filter(Polars.col("ID").eq(98))["LAST_APP_TIME"].to_a.first).to eq("2024-01-12")

          # Test all other rows have null LAST_APP_TIME
          other_rows = dataset.data.filter(!Polars.col("COMPANY_ID").is_in([1, 2, 3, 4, 10, 12]))
          expect(other_rows["LAST_APP_TIME"].null_count).to eq(other_rows.height)

          # Feature should be marked as computed
          feature.reload
          expect(feature.fit_at).to be_present
          expect(feature.needs_recompute).to be false

          dataset.reload
          expect(dataset.needs_refresh?).to be false
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
          feature.update(needs_recompute: false)
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
          feature.update!(applied_at: Time.current, fit_at: Time.now, needs_recompute: false)
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

    describe "Synchronous feature computation", :focus do
      let(:feature) do
        EasyML::Feature.create!(
          dataset: dataset,
          feature_class: "ZipFeature",
          name: "Zip Feature",
        )
      end

      let(:datasource) do
        EasyML::Datasource.create(
          name: "Batches",
          datasource_type: "file",
        )
      end

      let(:dataset) do
        EasyML::Dataset.create(
          name: "My Dataset",
          datasource: datasource,
          splitter_attributes: {
            splitter_type: "random",
          },
        )
      end

      it "computes features synchronously" do
        zips_dataset
        feature
        dataset.refresh
        dataset.columns.find_by(name: "ZIP").update(datatype: "string")
        dataset.refresh

        expect(dataset.data.columns).to include("POPULATION")
      end
    end
  end
end
