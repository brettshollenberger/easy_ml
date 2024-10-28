require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::RetrainingRun do
  include ModelSpecHelper
  let(:root_dir) do
    Rails.root
  end

  let(:datasource) do
    EasyML::Datasource.create(
      name: "Polars Datasource",
      datasource_type: :polars,
      df: df
    )
  end

  let(:dataset) do
    dataset_config[:datasource] = datasource
    EasyML::Dataset.create(
      name: "Dataset",
      **dataset_config
    )
  end

  let(:model_name) do
    "My Model"
  end
  let(:model) do
    model_config[:name] = model_name
    model_config[:task] = "regression"
    EasyML::Model.create(**model_config).tap do |model|
      model.model_file = model_file
      model.version = model_file.filename.gsub(/\.json/, "")
      model.save
      model.promote
    end
  end

  let(:retraining_job) do
    EasyML::RetrainingJob.create!(
      model: model.name,
      frequency: "day",
      at: 2,
      active: true,
      tuner_config: {
        n_trials: 5,
        objective: :mean_absolute_error,
        config: {
          learning_rate: { min: 0.01, max: 0.1 },
          n_estimators: { min: 1, max: 2 },
          max_depth: { min: 1, max: 5 }
        }
      }
    )
  end

  let(:retraining_run) do
    described_class.create!(
      retraining_job: retraining_job,
      status: "pending"
    )
  end

  describe "validations" do
    it "validates status inclusion" do
      run = described_class.new(retraining_job: retraining_job, status: "invalid")
      expect(run).not_to be_valid
      expect(run.errors[:status]).to include("is not included in the list")
    end
  end

  describe "#perform_retraining!" do
    context "with tuning frequency" do
      before do
        retraining_job.update!(tuning_frequency: "week")
      end

      it "performs tuning when tuning frequency is met" do
        allow(retraining_job).to receive(:should_tune?).and_return(true)

        expect(EasyML::Orchestrator).to receive(:train)
          .with(model.name, tuner: retraining_job.tuner_config)
          .and_call_original

        expect(retraining_run.perform_retraining!).to be true
        expect(retraining_job.reload.last_tuning_at).to be_present
      end

      it "skips tuning when tuning frequency is not met" do
        allow(retraining_job).to receive(:should_tune?).and_return(false)

        expect(EasyML::Orchestrator).to receive(:train)
          .with(model.name)
          .and_call_original

        expect(retraining_run.perform_retraining!).to be true
        expect(retraining_job.reload.last_tuning_at).to be_nil
      end
    end

    it "handles errors during retraining" do
      allow(EasyML::Orchestrator).to receive(:train).and_raise("Test error")

      expect(retraining_run.perform_retraining!).to be false
      expect(retraining_run.reload).to be_failed
      expect(retraining_run.error_message).to eq("Test error")
    end

    it "doesn't perform retraining if not pending" do
      retraining_run.update!(status: "completed")
      expect(retraining_run.perform_retraining!).to be false
    end
  end

  describe "status helpers" do
    it "provides status helper methods" do
      run = described_class.new(status: "pending")
      expect(run).to be_pending
      expect(run).not_to be_completed

      run.status = "completed"
      expect(run).to be_completed
      expect(run).not_to be_pending

      run.status = "failed"
      expect(run).to be_failed
      expect(run).not_to be_completed

      run.status = "running"
      expect(run).to be_running
      expect(run).not_to be_completed
    end
  end
end
