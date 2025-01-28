require "spec_helper"
require "support/model_spec_helper"
require "support/file_spec_helper"

RSpec.describe EasyML::Datasource do
  include ModelSpecHelper

  let(:today) do
    EasyML::Support::EST.parse("2024-10-01")
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
        fit_df = feature.fit_batch

        # Load the stored feature values
        stored_df = feature.query

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
        feature.fit_batch

        # Create a test dataframe for transformation
        test_df = Polars::DataFrame.new([
          { "LOAN_APP_ID" => "A2", "OTHER_COL" => "value" },
        ])

        # Transform the test data
        result_df = feature.transform_batch(test_df)

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
        let(:feature) do
          EasyML::Feature.create!(
            dataset: dataset,
            feature_class: "LastAppTime",
            name: "Last Application Time",
          )
        end

        let(:test_data) do
          [
            { "COMPANY_ID" => 1, "CREATED_AT" => "2024-01-01", "LOAN_APP_ID" => 1 },
            { "COMPANY_ID" => 2, "CREATED_AT" => "2024-01-02", "LOAN_APP_ID" => 2 },
          ]
        end

        let(:feature_instance) { instance_double("LastAppTime") }
        let(:batch_df) { Polars::DataFrame.new(test_data) }

        before do
          allow(LastAppTime).to receive(:new).and_return(feature_instance)
          allow(feature_instance).to receive(:fit).and_return(batch_df)
          allow_any_instance_of(EasyML::FeatureStore).to receive(:store).and_call_original
        end

        it "computes features using the feature class" do
          feature.fit_batch
          expect(feature_instance).to have_received(:fit).with(any_args)
        end

        it "stores the computed features" do
          feature.fit_batch
          expect(feature.query.size).to eq 2
        end

        it "returns the computed batch dataframe" do
          expect(feature.fit_batch).to eq(batch_df)
        end
      end
    end

    describe "#batch_size" do
      it "returns configured batch size from feature class" do
        feature = EasyML::Feature.create!(
          dataset: dataset,
          feature_class: "TestFeature",
          name: "Test Feature",
        )
        expect(feature.batch_size).to eq(5000)
      end

      it "has no batch size when not set, batch method not defined, and batch_size not set" do
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
          # Setup the dataset and feature to need recomputation
          zips_dataset
          feature
          dataset.refresh
          dataset.columns.find_by(name: "ZIP").update(datatype: "string")
          dataset.refresh
          clear_enqueued_jobs
          feature.reload.update(needs_fit: true)
          dataset.reload

          # Feature lazily creates the dataset, which triggers the refresh
          expect { dataset.refresh_async }.to have_enqueued_job(EasyML::RefreshDatasetJob).with(dataset.id)

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
          dataset.reload

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
          expect(feature.needs_fit).to be false

          dataset.reload
          expect(dataset.needs_refresh?).to be false
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
          dataset.reload

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
          expect(feature.needs_fit).to be false

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
        EasyML::Feature.clear_sha_cache!

        # Load V1 of the feature
        load File.join(Rails.root, "fixtures/feature_v1.rb")
        feature.save! # This will compute and store the SHA for V1
      end

      after(:each) do
        EasyML::Feature.clear_sha_cache!
      end

      context "when feature has different batch_size than its code" do
        it "is returned in needs_fit scope" do
          feature.update(batch_size: 100)
          expect(EasyML::Feature.needs_fit).to include(feature)
        end

        it "resets after running fit" do
          dataset.refresh

          feature.reload.update(needs_fit: true)
          expect(EasyML::Feature.needs_fit).to include(feature)

          feature.fit
          expect(EasyML::Feature.needs_fit).to_not include(feature)
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
          feature.update(needs_fit: false)
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

        it "is returned in needs_fit scope" do
          expect(EasyML::Feature.needs_fit).to include(unapplied_feature)
        end
      end

      context "when feature has been applied" do
        before do
          feature.update!(applied_at: Time.current, fit_at: Time.now, needs_fit: false)
        end

        it "is not returned in needs_fit scope if code hasn't changed" do
          expect(EasyML::Feature.needs_fit).not_to include(feature)
        end

        it "is returned in needs_fit scope if code has changed" do
          load File.join(Rails.root, "fixtures/feature_v2.rb")
          expect(EasyML::Feature.needs_fit).to include(feature)
        end
      end
    end

    describe "Synchronous feature computation" do
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
        expect(dataset.data.columns).to include("CITY")
        expect(dataset.data.columns).to include("STATE")
      end
    end

    describe "#needs_fit?" do
      let(:feature) do
        EasyML::Feature.create!(
          dataset: dataset,
          feature_class: "ZipFeature",
          name: "Zip Feature",
        )
      end

      context "when feature adapter does not respond to fit" do
        before do
          allow(feature.adapter).to receive(:respond_to?).with(:fit).and_return(false)
        end

        it "returns false" do
          expect(feature.needs_fit?).to be false
        end
      end

      context "when needs_fit flag is set" do
        before do
          feature.update(needs_fit: true)
        end

        it "returns true" do
          expect(feature.needs_fit?).to be true
        end
      end

      context "when code has changed" do
        before do
          feature.update(sha: "old_sha")
          allow(EasyML::Feature).to receive(:compute_sha).and_return("new_sha")
        end

        it "returns true" do
          expect(feature.needs_fit?).to be true
        end
      end

      context "when datasource has been refreshed after feature was fit" do
        before do
          feature.update(fit_at: 1.day.ago)
          dataset.datasource.update(refreshed_at: Time.current)
        end

        it "returns true" do
          expect(feature.needs_fit?).to be true
        end
      end

      context "when datasource has not been refreshed since feature was fit" do
        before do
          dataset.datasource.update(refreshed_at: 1.day.ago)
          feature.update(fit_at: Time.current, needs_fit: false)
        end

        it "returns false" do
          expect(feature.needs_fit?).to be false
        end
      end

      context "when feature has never been fit" do
        before do
          feature.update(fit_at: nil)
        end

        it "returns true" do
          expect(feature.needs_fit?).to be true
        end
      end

      context "when datasource has never been refreshed" do
        before do
          feature.update(fit_at: Time.current, needs_fit: false)
          dataset.datasource.update(refreshed_at: nil)
        end

        it "returns false" do
          expect(feature.needs_fit?).to be false
        end
      end

      context "when refresh_every period has elapsed" do
        before do
          feature.update(
            fit_at: 2.days.ago,
            needs_fit: false,
            refresh_every: 1.day.to_i,
          )
        end

        it "returns true" do
          expect(feature.needs_fit?).to be true
        end
      end

      context "when refresh_every period has not elapsed" do
        before do
          feature.update(
            fit_at: 12.hours.ago,
            needs_fit: false,
            refresh_every: 1.day.to_i,
          )
        end

        it "returns false" do
          expect(feature.needs_fit?).to be false
        end
      end

      context "when refresh_every is not set" do
        before do
          feature.update(
            fit_at: 2.days.ago,
            needs_fit: false,
            refresh_every: nil,
          )
        end

        it "returns false" do
          expect(feature.needs_fit?).to be false
        end
      end
    end

    describe "#update_from_feature_class" do
      let(:feature) do
        EasyML::Feature.create!(
          dataset: dataset,
          feature_class: TestFeatureClass.to_s,
          name: "Test Feature",
        )
      end

      it "updates refresh_every from feature configuration" do
        expect(feature.refresh_every).to eq(1.day.to_i)
      end

      it "converts refresh_every to integer" do
        allow(feature).to receive(:feature_class_config).and_return({ refresh_every: 1.day })
        feature.send(:update_from_feature_class)
        expect(feature.refresh_every).to be_a(Integer)
      end
    end
  end
end
