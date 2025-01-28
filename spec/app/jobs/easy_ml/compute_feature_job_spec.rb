require "spec_helper"
require "support/model_spec_helper"

RSpec.describe "EasyML::Feature Computation" do
  include ModelSpecHelper

  before(:each) do
    EasyML::Cleaner.clean
  end

  after(:each) do
    EasyML::Cleaner.clean
  end

  def process_all_jobs
    while Resque.peek(:easy_ml).any?
      worker = Resque::Worker.new(:easy_ml)
      worker.register_worker

      while job = worker.reserve
        worker.process(job)
      end

      worker.unregister_worker
    end
  end

  describe "feature computation with failures" do
    let(:dataset) { titanic_dataset }

    it "aborts all unrun jobs when any feature computation fails" do
      # Create failing feature first (position 1)
      failing_feature = dataset.features.create!(
        name: "failing_feature",
        feature_class: "FailingFeature",
        needs_fit: true,
        feature_position: 1,
      )

      # Create family size feature second (position 2)
      family_size_feature = dataset.features.create!(
        name: "family_size",
        feature_class: "FamilySizeFeature",
        needs_fit: true,
        feature_position: 2,
      )

      # Expect FamilySizeFeature to never receive fit
      expect_any_instance_of(FamilySizeFeature).not_to receive(:fit)

      # Attempt to fit features asynchronously
      expect {
        dataset.refresh!(async: true)
      }.to change { dataset.reload.workflow_status }.from("ready").to("analyzing")

      # Process all jobs in the queue
      process_all_jobs

      # Verify the results
      dataset.reload
      expect(dataset.workflow_status).to eq("failed")
      expect(dataset.events.last.status).to eq("failed")
      expect(dataset.events.last.stacktrace).to include("Intentional failure in feature computation")

      # Verify final states
      expect(dataset.reload.workflow_status).to eq("failed")
      expect(failing_feature.reload.workflow_status).to eq("failed")
      expect(family_size_feature.reload.workflow_status).to eq("ready")

      # Verify error was saved in EventContext
      error_event = dataset.events.last
      expect(error_event.status).to eq("failed")
      expect(error_event.context.context).to be_a(Polars::DataFrame)
    end
  end

  describe "feature computation ordering" do
    let(:dataset) { titanic_dataset }

    it "computes features in the correct order based on feature_position" do
      # Create family size plus one feature first but with higher position
      family_size_plus_one_feature = dataset.features.create!(
        name: "FamilySizePlusOne",
        feature_class: "FamilySizePlusOneFeature",
        needs_fit: true,
        feature_position: 2,
      )

      # Create family size feature second but with lower position
      family_size_feature = dataset.features.create!(
        name: "FamilySize",
        feature_class: "FamilySizeFeature",
        needs_fit: true,
        feature_position: 1,
      )

      # Track computation order
      computation_order = []

      RSpec::Mocks.with_temporary_scope do
        allow_any_instance_of(FamilySizeFeature).to receive(:fit).and_wrap_original do |method, *args|
          expect(computation_order).not_to include("FamilySizePlusOne"),
            "FamilySizePlusOne should not be computed before FamilySize is complete"
          computation_order << "FamilySize"
          method.call(*args)
        end

        allow_any_instance_of(FamilySizePlusOneFeature).to receive(:fit).and_wrap_original do |method, *args|
          computation_order << "FamilySizePlusOne"
          method.call(*args)
        end

        # Fit features asynchronously
        expect {
          dataset.refresh!(async: true)
        }.to change { dataset.reload.workflow_status }.from("ready").to("analyzing")

        # Process all jobs in the queue
        process_all_jobs
      end

      # Verify that all FamilySize computations happen before any FamilySizePlusOne
      family_size_index = computation_order.rindex("FamilySize")
      family_size_plus_one_index = computation_order.index("FamilySizePlusOne")
      expect(family_size_index).to be < family_size_plus_one_index,
        "Expected all FamilySize computations to complete before any FamilySizePlusOne computations begin"

      # Additional verification that no FamilySizePlusOne appears before the last FamilySize
      early_computations = computation_order[0..family_size_index]
      expect(early_computations).not_to include("FamilySizePlusOne"),
        "Found FamilySizePlusOne computation before all FamilySize computations were complete"

      # Verify the results
      dataset.reload
      expect(dataset.workflow_status).to eq("ready")

      # Get all passenger IDs
      passenger_ids = dataset.data["PassengerId"].to_a

      # Verify FamilySize was computed first
      family_size_values = family_size_feature.query(filter: Polars.col("PassengerId").is_in(passenger_ids))
      expect(family_size_values).not_to be_nil
      expect(family_size_values.shape[0]).to eq(passenger_ids.length)

      # Verify FamilySizePlusOne was computed correctly using FamilySize values
      family_size_plus_one_values = family_size_plus_one_feature.query(filter: Polars.col("PassengerId").is_in(passenger_ids))
      expect(family_size_plus_one_values).not_to be_nil
      expect(family_size_plus_one_values.shape[0]).to eq(passenger_ids.length)

      # Verify FamilySizePlusOne values are exactly FamilySize + 1 for all rows
      family_size_plus_one_values.join(
        family_size_values,
        on: "PassengerId",
      ).select([
        Polars.col("PassengerId"),
        Polars.col("FamilySizePlusOne"),
        Polars.col("FamilySize"),
      ]).with_column(
        (Polars.col("FamilySizePlusOne") - Polars.col("FamilySize")).alias("difference")
      ).select("difference").to_series.to_a.each do |diff|
        expect(diff).to eq(1)
      end
    end
  end

  describe "batch completion ordering" do
    let(:dataset) { titanic_dataset }

    it "completes all batches of a feature before starting the next feature", :focus do
      # Create family size plus one feature first but with higher position
      family_size_plus_one_feature = dataset.features.create!(
        name: "FamilySizePlusOne",
        feature_class: "FamilySizePlusOneFeature",
        needs_fit: true,
        feature_position: 2,
      )

      # Create family size feature second but with lower position
      family_size_feature = dataset.features.create!(
        name: "FamilySize",
        feature_class: "FamilySizeFeature",
        needs_fit: true,
        feature_position: 1,
      )

      # Track batch computation order
      batch_computation_order = []

      features_by_id = EasyML::Feature.all.group_by(&:id).transform_values(&:first)
      RSpec::Mocks.with_temporary_scope do
        idx = 0
        allow_any_instance_of(EasyML::Feature).to receive(:actually_fit_batch).and_wrap_original do |method, batch_args|
          feature = features_by_id[batch_args[:feature_id]]
          batch_computation_order << { feature: feature.name, batch_number: batch_args[:batch_number], subbatch_number: batch_args[:subbatch_number], call_order: idx }
          idx += 1
          method.call(batch_args)
        end

        # Fit features asynchronously
        expect {
          dataset.refresh!(async: true)
        }.to change { dataset.reload.workflow_status }.from("ready").to("analyzing")

        # Process all jobs in the queue
        process_all_jobs
      end

      # Extract all batch numbers for each feature
      family_size_batches = batch_computation_order.select { |entry| entry[:feature] == "FamilySize" }.map { |entry| entry[:batch_number] }
      family_size_plus_one_batches = batch_computation_order.select { |entry| entry[:feature] == "FamilySizePlusOne" }.map { |entry| entry[:batch_number] }

      # Verify that we have multiple batches for each fceature
      expect(family_size_batches.length).to be > 1, "Expected FamilySize to have multiple batches"
      expect(family_size_plus_one_batches.length).to be > 1, "Expected FamilySizePlusOne to have multiple batches"

      # Find the position of the last FamilySize batch and first FamilySizePlusOne batch
      last_family_size_index = batch_computation_order.rindex { |entry| entry[:feature] == "FamilySize" }
      first_family_size_plus_one_index = batch_computation_order.index { |entry| entry[:feature] == "FamilySizePlusOne" }

      # Verify FamilySizePlusOne starts after FamilySize completes
      expect(first_family_size_plus_one_index).to be > last_family_size_index,
        "Expected all FamilySize batches to complete before any FamilySizePlusOne batch begins"

      # Additional verification that no FamilySizePlusOne appears before the last FamilySize
      early_computations = batch_computation_order[0..last_family_size_index]
      expect(early_computations.none? { |entry| entry[:feature] == "FamilySizePlusOne" }).to be true

      # Verify the results
      dataset.reload
      expect(family_size_feature.reload.workflow_status).to eq("ready")
      expect(family_size_plus_one_feature.reload.workflow_status).to eq("ready")

      # Verify that FamilySizePlusOne values are correctly computed using FamilySize values
      passenger_ids = dataset.data["PassengerId"].to_a
      family_size_values = family_size_feature.query(filter: Polars.col("PassengerId").is_in(passenger_ids))
      family_size_plus_one_values = family_size_plus_one_feature.query(filter: Polars.col("PassengerId").is_in(passenger_ids))

      family_size_plus_one_values.join(
        family_size_values,
        on: "PassengerId",
      ).select([
        Polars.col("PassengerId"),
        Polars.col("FamilySizePlusOne"),
        Polars.col("FamilySize"),
      ]).with_column(
        (Polars.col("FamilySizePlusOne") - Polars.col("FamilySize")).alias("difference")
      ).select("difference").to_series.to_a.each do |diff|
        expect(diff).to eq(1)
      end
    end
  end
end
