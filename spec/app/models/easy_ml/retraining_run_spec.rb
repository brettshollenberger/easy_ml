require "spec_helper"

RSpec.describe EasyML::RetrainingRun do
  let(:retraining_job) do
    EasyML::RetrainingJob.create!(
      model: "test_model",
      frequency: "day",
      at: 2,
      active: true
    )
  end

  describe "associations" do
    let(:run) { described_class.new(retraining_job: retraining_job, status: "pending") }

    it "belongs to retraining job" do
      expect(run.retraining_job).to eq(retraining_job)
    end

    it "can belong to tuner job" do
      tuner_job = EasyML::TunerJob.create!(
        config: { test: true },
        model_id: 1
      )
      run.tuner_job = tuner_job
      expect(run.tuner_job).to eq(tuner_job)
    end
  end

  describe "callbacks" do
    describe "after_create" do
      it "updates retraining job last_run_at" do
        Timecop.freeze do
          expect do
            described_class.create!(
              retraining_job: retraining_job,
              status: "pending"
            )
          end.to change { retraining_job.reload.last_run_at }.to(Time.current)
        end
      end
    end
  end

  describe "status enum" do
    it "defines the correct statuses" do
      expect(described_class.statuses).to eq({
                                               "pending" => "pending",
                                               "running" => "running",
                                               "completed" => "completed",
                                               "failed" => "failed"
                                             })
    end

    it "allows setting valid statuses" do
      run = described_class.new(retraining_job: retraining_job, status: "pending")
      expect(run).to be_valid

      described_class.statuses.each_key do |status|
        run.status = status
        expect(run).to be_valid
      end
    end
  end
end
