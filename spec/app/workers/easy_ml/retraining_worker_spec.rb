require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::RetrainingWorker do
  include ModelSpecHelper
  describe "#perform" do
    let(:model_name) do
      "My Model"
    end
    let(:model) do
      model_config[:name] = model_name
      model_config[:task] = "regression"
      EasyML::Model.create(**model_config).tap do |model|
        model.model_file = model_file
        model.version = model_file.filename.gsub(/\.json/, "")
        model.fit
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
            n_estimators: { min: 1, max: 2 }
          }
        }
      )
    end

    let(:retraining_run) do
      EasyML::RetrainingRun.create!(
        retraining_job: retraining_job,
        status: :pending
      )
    end

    before do
      allow(EasyML::RetrainingRun).to receive(:find).with(retraining_run.id).and_return(retraining_run)
      allow(retraining_run).to receive(:perform_retraining!)
      allow(retraining_job).to receive(:model_must_exist).and_return(true)
    end

    it "unlocks the associated job after processing" do
      expect(retraining_job).to receive(:unlock!)

      subject.perform(retraining_run.id)
    end

    it "does not unlock the job after an error" do
      allow(retraining_run).to receive(:perform_retraining!).and_raise(StandardError, "Something went wrong")
      expect(retraining_job).to_not receive(:unlock!)

      expect { subject.perform(retraining_run.id) }.to raise_error(StandardError)
    end
  end
end
