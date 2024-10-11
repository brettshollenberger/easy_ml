require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::Core::Tuner do
  include ModelSpecHelper
  let(:model_class) do
    EasyML::Core::Models::XGBoost
  end

  let(:n_trials) do
    5
  end

  describe "Model Tuner" do
    it "sets defaults" do
      expect_any_instance_of(EasyML::Core::Tuner::XGBoostAdapter).to receive(:run_trial) do |adapter|
        expect(adapter.config[:learning_rate][:max]).to eq 0.1
        expect(adapter.config[:learning_rate][:log]).to eq true
      end

      EasyML::Core::Tuner.new(
        n_trials: n_trials,
        model: model,
        config: {
          learning_rate: {
            min: 0.01
          }
        }
      ).tune
    end

    it "tunes the model" do
      expect(::XGBoost).to receive(:train).exactly(n_trials).times do |hyperparams, _dmat, _evals|
        expect(hyperparams["learning_rate"]).to be_between(0.01, 0.1)
      end

      EasyML::Core::Tuner.new(
        n_trials: n_trials,
        model: model,
        config: {
          learning_rate: {
            min: 0.01
          }
        }
      ).tune
    end

    it "returns metrics", :focus do
      expect do
        EasyML::Core::Tuner.new(
          n_trials: n_trials,
          model: model,
          objective: :mean_absolute_error,
          config: {
            learning_rate: {
              min: 0.01
            }
          }
        ).tune
      end.to_not raise_error
    end
  end
end
