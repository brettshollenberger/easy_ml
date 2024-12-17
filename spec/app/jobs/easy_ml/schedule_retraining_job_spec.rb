require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::ScheduleRetrainingJob do
  include ModelSpecHelper

  let(:model_name) do
    "My Model"
  end
  let(:model) do
    pretrain_loans_model
  end
  before(:all) do
    EasyML::Cleaner.clean
  end
  after(:all) do
    EasyML::Cleaner.clean
  end

  let(:retraining_job) do
    EasyML::RetrainingJob.create!(
      model: model,
      frequency: "day",
      active: true,
      metric: :mean_absolute_error,
      threshold: 0,
      at: { hour: 2 },
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
      model2 = model.dup
      model2.update(name: "Another One")
      job2.model = model2
      job2.save
      job2
    end
    let!(:inactive_job) do
      job2 = retraining_job.dup
      model3 = model.dup
      model3.update(name: "A different one")
      job2.model = model3
      job2.active = false
      job2.save
      job2
    end

    before do
      allow(job1).to receive(:should_run?).and_return(true)
      allow(job2).to receive(:should_run?).and_return(true)
      allow(EasyML::RetrainingJob).to receive(:active).and_return([job1, job2])
    end

    it "creates runs and enqueues worker jobs for current jobs" do
      model.train(async: false)

      expect do
        subject.perform
      end.to change(EasyML::RetrainingRun, :count).by(2)
    end
  end
end
