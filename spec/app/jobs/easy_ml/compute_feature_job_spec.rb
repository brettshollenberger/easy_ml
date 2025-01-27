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
      job = Resque.reserve(:easy_ml)
      job.perform
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
      expect(dataset.events.last.event_type).to eq("error")
      expect(dataset.events.last.message).to include("Intentional failure in feature computation")
    end
  end

  describe "feature computation ordering" do
    let(:dataset) { titanic_dataset }

    it "computes features in the correct order based on feature_position", :focus do
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
end
