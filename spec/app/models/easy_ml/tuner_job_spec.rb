require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::TunerJob, type: :model do
  include ModelSpecHelper

  let(:model) do
    pretrain_loans_model
  end
  before(:all) do
    EasyML::Cleaner.clean
  end
  after(:all) do
    EasyML::Cleaner.clean
  end

  describe "validations" do
    let(:tuner_job) { EasyML::TunerJob.new(model: model, direction: "minimize", config: { learning_rate: 0.5 }) }

    it "requires config to be present" do
      tuner_job.config = nil
      expect(tuner_job).not_to be_valid
      expect(tuner_job.errors[:config]).to include("can't be blank")
    end

    it "validates direction is either minimize or maximize" do
      tuner_job.direction = "invalid"
      expect(tuner_job).not_to be_valid
      expect(tuner_job.errors[:direction]).to include("is not included in the list")

      tuner_job.direction = "minimize"
      expect(tuner_job).to be_valid

      tuner_job.direction = "maximize"
      expect(tuner_job).to be_valid
    end
  end

  describe "#best_run" do
    context "when direction is minimize" do
      let(:tuner_job) do
        EasyML::TunerJob.create!(
          model: model,
          direction: "minimize",
          config: { "param1" => "value1" },
        )
      end

      it "returns the run with lowest value" do
        EasyML::TunerRun.create!(
          tuner_job: tuner_job,
          value: 0.5,
          hyperparameters: { "param1" => "value1" },
          trial_number: 1,
        )
        run2 = EasyML::TunerRun.create!(
          tuner_job: tuner_job,
          value: 0.3,
          hyperparameters: { "param1" => "value1" },
          trial_number: 2,
        )
        EasyML::TunerRun.create!(
          tuner_job: tuner_job,
          value: 0.7,
          hyperparameters: { "param1" => "value1" },
          trial_number: 3,
        )

        expect(tuner_job.best_run).to eq(run2)
      end
    end

    context "when direction is maximize" do
      let(:tuner_job) do
        EasyML::TunerJob.create!(
          model: model,
          direction: "maximize",
          config: { "param1" => "value1" },
        )
      end

      it "returns the run with highest value" do
        EasyML::TunerRun.create!(
          tuner_job: tuner_job,
          value: 0.5,
          hyperparameters: { "param1" => "value1" },
          trial_number: 1,
        )
        EasyML::TunerRun.create!(
          tuner_job: tuner_job,
          value: 0.3,
          hyperparameters: { "param1" => "value1" },
          trial_number: 2,
        )
        run3 = EasyML::TunerRun.create!(
          tuner_job: tuner_job,
          value: 0.7,
          hyperparameters: { "param1" => "value1" },
          trial_number: 3,
        )

        expect(tuner_job.best_run).to eq(run3)
      end
    end

    context "when no runs exist" do
      let(:tuner_job) do
        EasyML::TunerJob.create!(
          model: model,
          direction: "minimize",
          config: { "param1" => "value1" },
        )
      end

      it "returns nil" do
        expect(tuner_job.best_run).to be_nil
      end
    end
  end
end
