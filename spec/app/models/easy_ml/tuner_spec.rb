require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::Core::Tuner do
  include ModelSpecHelper

  let(:dataset) do
    loans_dataset
  end

  let(:model) do
    model_config[:name] = "My Model"
    model_config[:task] = "regression"
    EasyML::Model.create(**model_config).tap do |model|
      model.pending_run
    end
  end

  let(:n_trials) do
    5
  end

  let(:mock_run) { instance_double(Wandb::Run) }
  let(:mock_model) { instance_double(XGBoost::Booster) }
  let(:callback_params) do
    {
      project_name: "my-great-project",
    }
  end

  let(:model_config) do
    {
      model_type: "xgboost",
      task: task,
      dataset: dataset,
      callbacks: [
        { wandb: { project_name: "my-great-project" } },
      ],
      hyperparameters: {
        booster: :gbtree,
        learning_rate: learning_rate,
        max_depth: max_depth,
        objective: objective,
      },
    }
  end

  let(:tuner_params) do
    {
      n_trials: n_trials,
      model: model,
      objective: :mean_absolute_error,
      config: {
        learning_rate: { min: 0.01, max: 0.1 },
        n_estimators: { min: 1, max: 2 },
        max_depth: { min: 1, max: 5 },
      },
    }
  end

  before do
    allow(Wandb).to receive(:login).and_return(true)
    allow(Wandb).to receive(:init).and_return(true)
    allow(Wandb).to receive(:current_run).and_return(mock_run)
    allow(Wandb).to receive(:define_metric).and_return(true)
    allow(mock_run).to receive(:config=)
    allow(mock_run).to receive(:url).and_return("https://wandb.ai")
    allow(Wandb).to receive(:log)
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
            min: 0.01,
          },
          n_estimators: { min: 1, max: 2 },
        },
      ).tune
    end

    it "recommends hyperparameters within range" do
      expect(::XGBoost).to receive(:train).exactly(n_trials + 1).times do |hyperparams, _dmat, _evals|
        expect(hyperparams["learning_rate"]).to be_between(0.01, 0.1)
      end.and_call_original

      EasyML::Core::Tuner.new(
        n_trials: n_trials,
        model: model,
        objective: :mean_absolute_error,
        config: {
          learning_rate: {
            min: 0.01,
          },
          n_estimators: { min: 1, max: 2 },
        },
      ).tune
    end

    it "returns best params" do
      best_params = EasyML::Core::Tuner.new(tuner_params).tune.with_indifferent_access

      expect(best_params["learning_rate"]).to be_between(0.01, 0.1)
      expect(best_params["n_estimators"]).to be_between(0, 2)
      expect(best_params["max_depth"]).to be_between(1, 5)
    end

    it "configures custom params for callbacks" do
      EasyML::Configuration.configure do |config|
        config.wandb_api_key = "my-api-key"
      end

      tuner = EasyML::Core::Tuner.new(tuner_params)
      wandb_callback = model.callbacks.detect { |cb| cb.class == Wandb::XGBoostCallback }

      expect(wandb_callback).to receive(:before_training).exactly(n_trials + 1).times.and_call_original
      puts tuner.project_name
      expect(Wandb).to receive(:init).with(project: tuner.project_name).at_least(:once).and_return(false)

      tuner.tune
    end

    it "accepts custom evaluator" do
      class CustomEvaluator
        def evaluate(y_pred: nil, y_true: nil, x_true: nil, dataset: nil)
          1
        end
      end

      EasyML::Core::ModelEvaluator.register(:custom, CustomEvaluator, :regression)
      model.get_retraining_job.update(metric: :custom, threshold: 10, direction: "minimize")
      model.save
      tuner = EasyML::Core::Tuner.new(tuner_params.merge!(model: model))
      tuner.tune

      expect(tuner.results).to eq([1, 1, 1, 1, 1])
    end

    describe "Tuning Job Tracking" do
      it "creates a tuner job" do
        existing_tuner_job_count = EasyML::TunerJob.count
        tuner = EasyML::Core::Tuner.new(tuner_params)
        new_count = EasyML::TunerJob.count
        expect(new_count).to eq(existing_tuner_job_count + 1)

        job = EasyML::TunerJob.last
        expect(job.config).to include(
          "n_trials" => n_trials,
          "objective" => "mean_absolute_error",
          "hyperparameter_ranges" => {
            "learning_rate" => { "min" => 0.01, "max" => 0.1 },
            "n_estimators" => { "min" => 1, "max" => 2 },
            "max_depth" => { "min" => 1, "max" => 5 },
          },
        )
      end

      it "creates tuner runs for each trial" do
        tuner = EasyML::Core::Tuner.new(tuner_params)
        expect { tuner.tune }.to change(EasyML::TunerRun, :count).by(n_trials)

        runs = EasyML::TunerRun.last(n_trials)
        runs.each do |run|
          expect(run.hyperparameters).to include(
            "learning_rate",
            "n_estimators",
            "max_depth"
          )
          expect(run.value).to be_present
        end
      end

      it "sets best_tuner_run_id" do
        tuner = EasyML::Core::Tuner.new(tuner_params)
        tuner.tune

        job = EasyML::TunerJob.last
        best_run = job.tuner_runs.order(value: :asc).first
        expect(job.best_tuner_run_id).to eq(best_run.id)
      end
    end
  end
end
