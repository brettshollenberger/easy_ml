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
        dataset.fit_features(async: true)
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
      # Create family size feature first (position 1)
      family_size_feature = dataset.features.create!(
        name: "FamilySize",
        feature_class: "FamilySizeFeature",
        needs_fit: true,
        feature_position: 1,
      )

      # Create family size plus one feature second (position 2)
      family_size_plus_one_feature = dataset.features.create!(
        name: "FamilySizePlusOne",
        feature_class: "FamilySizePlusOneFeature",
        needs_fit: true,
        feature_position: 2,
      )

      # Fit features asynchronously
      expect {
        dataset.refresh!(async: true)
      }.to change { dataset.reload.workflow_status }.from("ready").to("analyzing")

      # Process all jobs in the queue
      process_all_jobs

      # Verify the results
      dataset.reload
      expect(dataset.workflow_status).to eq("ready")

      # Verify FamilySizePlusOne values are exactly FamilySize + 1
      expect(
        dataset.data["FamilySizePlusOne"].eq(dataset.data["FamilySize"] + 1).to_a
      ).to all(be_truthy)
    end
  end
end
