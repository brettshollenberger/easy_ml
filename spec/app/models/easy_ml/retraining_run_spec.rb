require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::RetrainingRun do
  include ModelSpecHelper

  let(:model_name) do
    "My Model"
  end
  let(:model) do
    EasyML::Model.create(**loans_model_config).tap do |model|
      model.dataset.refresh
      model.update(name: model_name)
    end
  end
  let(:mock_run) { instance_double(Wandb::Run) }

  before do
    allow(Wandb).to receive(:login).and_return(true)
    allow(Wandb).to receive(:init).and_return(true)
    allow(Wandb).to receive(:current_run).and_return(mock_run)
    allow(Wandb).to receive(:define_metric).and_return(true)
    allow(mock_run).to receive(:config=)
    allow(mock_run).to receive(:url).and_return("https://wandb.ai")
    allow(Wandb).to receive(:log)
  end

  let(:retraining_job) do
    EasyML::RetrainingJob.create!(
      model: model,
      frequency: "day",
      at: {
        hour: 2,
      },
      active: true,
      metric: :root_mean_squared_error,
      threshold: 1000,
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

  let(:retraining_run) do
    described_class.create!(
      model: model,
      retraining_job: retraining_job,
      status: "pending",
    )
  end

  describe "validations" do
    it "validates status inclusion" do
      run = described_class.new(retraining_job: retraining_job, status: "invalid")
      expect(run).not_to be_valid
      expect(run.errors[:status]).to include("is not included in the list")
    end
  end

  describe "#model.train" do
    context "with tuning frequency" do
      before do
        retraining_job.update!(tuning_frequency: "week")
      end

      it "performs tuning when tuning frequency is met" do
        allow(retraining_job).to receive(:should_tune?).and_return(true)
        retraining_run.model.train(async: false)
        expect(retraining_job.reload.last_tuning_at).to be_present
      end

      it "skips tuning when tuning frequency is not met" do
        allow(retraining_job).to receive(:should_tune?).and_return(false)

        x_train, y_train = model.dataset.train(split_ys: true)
        y_train["rev"] = Polars::Series.new(Array.new(5) { 10_000 })
        allow_any_instance_of(EasyML::Dataset).to receive(:train).and_return([x_train, y_train])

        retraining_run.model.train(async: false)
        expect(retraining_job.reload.last_tuning_at).to be_nil
      end
    end

    it "saves best_params" do
      allow(retraining_job).to receive(:should_tune?).and_return(true)

      model.train(async: false)
      expect(model.last_run.best_params.keys).to include("learning_rate", "n_estimators", "max_depth")
    end

    it "trains in batches when not using tuner" do
      retraining_job.update(tuner_config: nil, batch_mode: true, batch_size: 100, batch_overlap: 2)
      expect_any_instance_of(EasyML::Model).to receive(:fit_in_batches).and_call_original

      model.train(async: false)
    end

    it "trains in batches when using tuner" do
      allow(retraining_job).to receive(:should_tune?).and_return(true)

      retraining_job.update(batch_mode: true, batch_size: 100, batch_overlap: 2, batch_key: "business_name")
      expect_any_instance_of(EasyML::Model).to receive(:fit_in_batches).at_least(:once).and_call_original

      retraining_run.model.train(async: false)
    end

    it "trains NOT in batches when no batches configured" do
      allow(retraining_job).to receive(:should_tune?).and_return(true)

      expect_any_instance_of(EasyML::Model).to_not receive(:fit_in_batches)

      retraining_run.model.train(async: false)
    end

    it "handles errors during retraining" do
      model
      allow_any_instance_of(EasyML::Model).to receive(:fit).and_raise("Test error")

      retraining_run.model.train(async: false)
      expect(retraining_run.reload).to be_failed
      expect(retraining_run.error_message).to eq("Test error")
    end

    it "doesn't perform retraining if not pending" do
      retraining_run.update!(status: "success")
      retraining_run.model.train(async: false)
    end

    context "with model evaluation" do
      def setup_evaluation(training_model, y_pred, y_true, call_original = false)
        # Set up our test expectations on the forked model
        allow_any_instance_of(EasyML::Dataset).to receive(:refresh!).and_return(true)
        allow_any_instance_of(EasyML::Dataset).to receive(:test).with(any_args).and_return([
          Polars::DataFrame.new({ nums: [1, 2, 3] }), y_true,
        ])
        allow(training_model).to receive(:predict).and_return(y_pred)
        allow(training_model).to receive(:deployable?).and_return(true)
        allow(training_model).to receive(:cannot_deploy_reasons).and_return([])
        allow(training_model).to receive(:reload).and_return(training_model)
        allow(training_model).to receive_message_chain(:bump_versions).and_call_original

        allow(training_model).to receive_message_chain(:save_model_file).and_return(true)

        training_model
      end

      let(:custom_evaluator) do
        Class.new do
          def metric
            :custom
          end

          def direction
            "maximize"
          end

          def evaluate(y_pred:, y_true:, x_true:, dataset:)
            # Simple custom metric for testing
            (y_pred.sum - y_true.sum).abs
          end
        end
      end

      before do
        # Register the custom evaluator
        EasyML::Core::ModelEvaluator.register(:custom, custom_evaluator, :regression)
      end

      context "with basic evaluator" do
        before do
          retraining_job.update!(
            threshold: 100,
          )
          model.train(async: false)
          model.deploy(async: false)
        end

        it "DOES NOT deploy model when RMSE is below threshold IF auto_deploy is disabled" do
          retraining_job.update(auto_deploy: false)

          original_model = EasyML::Model.find_by(name: model.name).latest_version
          setup_evaluation(model, [1, 2, 3], [1, 2, 3])

          expect { model.train(async: false) }.to_not have_enqueued_job(EasyML::DeployJob)
          perform_enqueued_jobs

          original_model.reload
          expect(original_model).to be_inference

          expect(EasyML::Deploy.count).to eq 1
          expect(EasyML::ModelHistory.count).to eq 1
        end

        it "deploys model when RMSE is below threshold AND auto_deploy is enabled" do
          retraining_job.update(auto_deploy: true)

          setup_evaluation(model, [1, 2, 3], [1, 2, 3])
          original_model = model.latest_version

          expect { model.train(async: false) }.to have_enqueued_job(EasyML::DeployJob)
          perform_enqueued_jobs

          original_model.reload
          expect(original_model).to be_retired

          trained_model = EasyML::Model.find_by(name: model.name).latest_version
          retraining_run = model.last_run
          expect(trained_model).to be_present
          expect(trained_model.id).to_not eq original_model.id
          expect(trained_model).to be_inference # after promotion
          expect(retraining_run.reload).to be_deployed

          deploy = EasyML::Deploy.last
          expect(deploy.trigger).to eq "manual"
          expect(deploy.model.id).to eq original_model.id
          expect(deploy.model_file_id).to eq trained_model.model_file_id
          expect(deploy.retraining_run_id).to eq retraining_run.id
        end

        it "does not deploy model when RMSE is above threshold" do
          retraining_job.update(auto_deploy: true)

          setup_evaluation(model, [1, 2, 3], [100, 200, 300])
          original_model = EasyML::Model.find_by(name: model.name).latest_version

          expect { model.train(async: false) }.to_not have_enqueued_job(EasyML::DeployJob)

          original_model.reload
          expect(original_model).to_not be_retired

          training_model = EasyML::Model.where(name: model.name)
          run = model.last_run
          expect(training_model).to be_present
          expect(retraining_run.reload).to_not be_deployed
        end

        it "logs all metrics" do
          retraining_job.update(auto_deploy: true)

          setup_evaluation(model, [1, 2, 3], [1, 2, 3])
          original_model = EasyML::Model.find_by(name: model.name).latest_version

          expect { model.train(async: false) }.to have_enqueued_job(EasyML::DeployJob)
          perform_enqueued_jobs

          original_model.reload
          expect(original_model).to be_retired

          trained_model = EasyML::Model.find_by(name: model.name).latest_version
          expect(trained_model.root_mean_squared_error).to eq 0.0
          expect(trained_model.evals).to match(hash_including({
                                                                "r2_score" => 1.0,
                                                                "mean_squared_error" => 0.0,
                                                                "mean_absolute_error" => 0.0,
                                                                "root_mean_squared_error" => 0.0,
                                                              }))
        end
      end

      context "with custom evaluator" do
        before do
          retraining_job.update!(
            metric: :custom,
            threshold: 1000,
          )
          model.train(async: false)
          model.deploy(async: false)
        end

        it "uses custom evaluator for promotion decision" do
          retraining_job.update(auto_deploy: true)
          model.update(metrics: model.metrics + [:custom])

          original_model = model.latest_version

          setup_evaluation(model, [1, 2, 3], [2000, 3000, 4000])

          model.train(async: false)
          perform_enqueued_jobs

          retraining_run = model.last_run
          expect(retraining_run.metric_value).to eq 8994.0
          expect(retraining_run.threshold).to eq 1_000
          expect(retraining_run.threshold_direction).to eq "maximize"
          expect(retraining_run.deployable).to eq true
          expect(retraining_run).to be_deployed
          expect(original_model.reload).to be_retired

          trained_model = EasyML::Model.find_by(name: model.name).latest_version
          expect(trained_model.id).to_not eq original_model.id
          expect(trained_model.last_run).to eq retraining_run

          expect(trained_model.custom).to eq 8994.0
          expect(trained_model.evals).to match(hash_including({
                                                                "custom" => 8994.0,
                                                              }))
        end
      end

      context "With callbacks" do
        it "passes metadata from the tuner to the retraining_run" do
          EasyML::Configuration.configure do |config|
            config.wandb_api_key = "test_key"
          end

          allow_any_instance_of(EasyML::RetrainingRun).to receive(:should_tune?).and_return(true)
          retraining_job
          setup_evaluation(model, [1, 2, 3], [1, 2, 3], true)
          m = EasyML::Model.find_by(name: model.name)
          m.train(async: false)

          run = m.last_run
          expect(run.wandb_url).to match(/https:\/\/wandb.ai/)
          m.model_file.cleanup([m.model_file.full_path]) # Keep only the original file
        end
      end
    end
  end

  describe "status helpers" do
    it "provides status helper methods" do
      run = described_class.new(status: "pending")
      expect(run).to be_pending
      expect(run).not_to be_success

      run.status = "success"
      expect(run).to be_success
      expect(run).not_to be_pending

      run.status = "failed"
      expect(run).to be_failed
      expect(run).not_to be_success

      run.status = "running"
      expect(run).to be_running
      expect(run).not_to be_success
    end
  end
end
