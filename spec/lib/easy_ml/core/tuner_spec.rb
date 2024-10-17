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

  let(:mock_run) { instance_double(Wandb::Run) }
  let(:mock_model) { instance_double(XGBoost::Booster) }
  let(:callback_params) do
    {
      project_name: "my-great-project"
    }
  end

  let(:model_config) do
    {
      root_dir: root_dir,
      task: task,
      dataset: dataset,
      callbacks: [
        { wandb: { project_name: "my-great-project" } }
      ],
      hyperparameters: {
        learning_rate: learning_rate,
        max_depth: max_depth,
        objective: objective
      }
    }
  end

  let(:model) do
    model_class.new(model_config)
  end

  let(:tuner_params) do
    {
      n_trials: n_trials,
      model: model,
      objective: :mean_absolute_error,
      config: {
        learning_rate: { min: 0.01, max: 0.1 },
        n_estimators: { min: 1, max: 2 },
        max_depth: { min: 1, max: 5 }
      }
    }
  end

  before do
    Timecop.freeze(EST.parse("2024-10-17").beginning_of_day)
    allow(Wandb).to receive(:login).and_return(true)
    allow(Wandb).to receive(:init).and_return(true)
    allow(Wandb).to receive(:current_run).and_return(mock_run)
    allow(Wandb).to receive(:define_metric).and_return(true)
    allow(mock_run).to receive(:config=)
    allow(Wandb).to receive(:log)
    Timecop.return
  end

  describe "Model Tuner" do
    it "sets defaults" do
      expect_any_instance_of(EasyML::Core::Tuner::Adapters::XGBoostAdapter).to receive(:run_trial).exactly(n_trials).times do |adapter|
        expect(adapter.config[:learning_rate][:max]).to eq 0.1
        expect(adapter.config[:learning_rate][:log]).to eq true
      end.and_call_original

      EasyML::Core::Tuner.new(
        n_trials: n_trials,
        model: model,
        objective: :mean_absolute_error,
        config: {
          learning_rate: {
            min: 0.01
          },
          n_estimators: { min: 1, max: 2 }
        }
      ).tune
    end

    it "recommends hyperparameters within range" do
      expect(::XGBoost).to receive(:train).exactly(n_trials).times do |hyperparams, _dmat, _evals|
        expect(hyperparams["learning_rate"]).to be_between(0.01, 0.1)
      end.and_call_original

      EasyML::Core::Tuner.new(
        n_trials: n_trials,
        model: model,
        objective: :mean_absolute_error,
        config: {
          learning_rate: {
            min: 0.01
          },
          n_estimators: { min: 1, max: 2 }
        }
      ).tune
    end

    it "returns best params" do
      best_params = EasyML::Core::Tuner.new(tuner_params).tune

      expect(best_params["learning_rate"]).to be_between(0.01, 0.1)
      expect(best_params["n_estimators"]).to be_between(0, 2)
      expect(best_params["max_depth"]).to be_between(1, 5)
    end

    it "configures custom params for callbacks" do
      expect_any_instance_of(Wandb::XGBoostCallback).to receive(:before_training).exactly(5).times.and_call_original

      tuner = EasyML::Core::Tuner.new(tuner_params)
      tuner.tune
      expect(tuner.model.callbacks.first.project_name).to match(/my-great-project_\d{4}_\d{2}_\d{2}/)
    end

    it "accepts custom evaluator" do
      class CustomEvaluator
        def evaluate(y_pred: nil, y_true: nil, x_true: nil)
          1
        end
      end
      model.evaluator = CustomEvaluator

      tuner = EasyML::Core::Tuner.new(tuner_params)
      tuner.tune

      expect(tuner.results).to eq([1, 1, 1, 1, 1])
    end
  end
end
