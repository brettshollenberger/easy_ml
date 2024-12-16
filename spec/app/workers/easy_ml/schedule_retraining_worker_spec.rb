require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::ScheduleRetrainingJob do
  include ModelSpecHelper

  let(:model_name) do
    "My Model"
  end
  let(:model) do
    pretrain_loans_model.tap do |model|
      model.deploy
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
          max_depth: { min: 1, max: 5 },
        },
      },
    )
  end
  describe "#perform" do
    let!(:job1) { retraining_job }
    let!(:job2) do
      job2 = retraining_job.dup
      job2.model = "Different Model"
      allow(job2).to receive(:model_must_exist).and_return(true)
      job2.save
      job2
    end
    let!(:inactive_job) do
      job2 = retraining_job.dup
      job2.model = "Another One"
      allow(job2).to receive(:model_must_exist).and_return(true)
      job2.active = false
      job2.save
      job2
    end

    before do
      allow(job1).to receive(:should_run?).and_return(true)
      allow(job2).to receive(:should_run?).and_return(true)
      allow(EasyML::RetrainingJob).to receive(:current).and_return([job1, job2])
    end

    it "creates runs and enqueues worker jobs for current jobs" do
      expect do
        subject.perform
      end.to change(EasyML::RetrainingRun, :count).by(2)

      expect(EasyML::RetrainingJob).to have_enqueued_sidekiq_job(EasyML::RetrainingRun.last.id)
      expect(EasyML::RetrainingJob).to have_enqueued_sidekiq_job(EasyML::RetrainingRun.last(2).first.id)
    end

    it "only processes jobs that can be locked" do
      allow(job1).to receive(:lock_job!).and_return(false)
      allow(job2).to receive(:lock_job!).and_return(true)

      expect do
        subject.perform
      end.to change(EasyML::RetrainingRun, :count).by(1)

      expect(EasyML::RetrainingJob).to have_enqueued_sidekiq_job(EasyML::RetrainingRun.last.id)
    end

    it "unlocks job if run creation fails" do
      allow(job1.retraining_runs).to receive(:create!).and_raise("Test error")
      expect(job1).to receive(:unlock_job!)

      subject.perform
    end
  end
end
