require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::RetrainingRun do
  include ModelSpecHelper

  before(:all) do
    EasyML::Cleaner.clean
  end
  after(:all) do
    EasyML::Cleaner.clean
  end
  let(:model_name) do
    "My Model"
  end
  let(:model) do
    EasyML::Model.create(**loans_model_config).tap do |model|
      model.fit
      model.deploy
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

  describe "#perform_retraining!" do
    context "with tuning frequency" do
      before do
        retraining_job.update!(tuning_frequency: "week")
      end

      it "performs tuning when tuning frequency is met" do
        allow(retraining_job).to receive(:should_tune?).and_return(true)

        expect(EasyML::Orchestrator).to receive(:train)
                                          .with(model.name, tuner: retraining_job.tuner_config, evaluator: retraining_job.evaluator)
                                          .and_call_original

        expect(retraining_run.perform_retraining!).to be true
        expect(retraining_job.reload.last_tuning_at).to be_present
      end

      it "skips tuning when tuning frequency is not met" do
        allow(retraining_job).to receive(:should_tune?).and_return(false)

        expect(EasyML::Orchestrator).to receive(:train)
                                          .with(model.name, evaluator: retraining_job.evaluator)
                                          .and_call_original

        x_train, y_train = model.dataset.train(split_ys: true)
        y_train["rev"] = Polars::Series.new(Array.new(5) { 10_000 })
        allow_any_instance_of(EasyML::Dataset).to receive(:train).and_return([x_train, y_train])

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
      retraining_run.update!(status: "success")
      expect(retraining_run.perform_retraining!).to be false
    end

    context "with model evaluation" do
      def setup_evaluation(y_pred, y_true, call_original = false)
        # Only stub train to avoid the actual training process
        a = allow(EasyML::Orchestrator).to receive(:train) do |model_name|
          training_model = EasyML::Model.find_by(name: model_name)

          # Set up our test expectations on the forked model
          allow_any_instance_of(EasyML::Dataset).to receive(:refresh!).and_return(true)
          allow_any_instance_of(EasyML::Dataset).to receive_message_chain(:target, :present?).and_return(true)
          allow_any_instance_of(EasyML::Dataset).to receive(:lock).and_return(true)
          allow_any_instance_of(EasyML::Dataset).to receive(:test).and_return([[1, 2, 3], y_true])
          allow(training_model).to receive(:predict).and_return(y_pred)
          allow(training_model).to receive(:deployable?).and_return(true)
          allow(training_model).to receive(:cannot_deploy_reasons).and_return([])
          allow(training_model).to receive(:reload).and_return(training_model)
          allow(training_model).to receive_message_chain(:bump_versions).and_call_original

          allow(training_model).to receive_message_chain(:save_model_file).and_return(true)

          training_model
        end

        return unless call_original

        a.and_call_original
      end

      let(:custom_evaluator) do
        Class.new do
          def metric
            :custom
          end

          def direction
            "maximize"
          end

          def evaluate(y_pred:, y_true:, x_true:)
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
        end

        it "DOES NOT deploy model when RMSE is below threshold IF auto_deploy is disabled" do
          retraining_job.update(auto_deploy: false)

          setup_evaluation([1, 2, 3], [1, 2, 3])
          original_model = EasyML::Model.find_by(name: model.name).latest_snapshot
          expect(retraining_run.perform_retraining!).to be true

          expect(EasyML::DeployWorker.jobs.count).to eq 0

          original_model.reload
          expect(original_model).to be_inference

          expect(EasyML::Deploy.count).to eq 0
          expect(EasyML::ModelHistory.count).to eq 1
        end

        it "deploys model when RMSE is below threshold AND auto_deploy is enabled" do
          retraining_job.update(auto_deploy: true)

          setup_evaluation([1, 2, 3], [1, 2, 3])
          original_model = EasyML::Model.find_by(name: model.name).latest_snapshot
          expect(retraining_run.perform_retraining!).to be true

          expect(EasyML::DeployWorker.jobs.count).to eq 1
          Sidekiq::Worker.drain_all

          original_model.reload
          expect(original_model).to be_retired

          trained_model = EasyML::Model.find_by(name: model.name).latest_snapshot
          expect(trained_model).to be_present
          expect(trained_model.id).to_not eq original_model.id
          expect(trained_model).to be_inference # after promotion
          expect(trained_model.retraining_runs.first).to eq retraining_run
          expect(retraining_run.reload).to be_success

          deploy = EasyML::Deploy.last
          expect(deploy.trigger).to eq "manual"
          expect(deploy.model.id).to eq original_model.id
          expect(deploy.model_file_id).to eq trained_model.model_file_id
          expect(deploy.retraining_run_id).to eq retraining_run.id
        end

        it "does not deploy model when RMSE is above threshold" do
          retraining_job.update(auto_deploy: true)

          setup_evaluation([1, 2, 3], [100, 200, 300])
          original_model = EasyML::Model.find_by(name: model.name).latest_snapshot
          expect(retraining_run.perform_retraining!).to be true

          expect(EasyML::DeployWorker.jobs.count).to eq 0

          original_model.reload
          expect(original_model).to_not be_retired

          training_model = EasyML::Model.where(name: model.name)
          expect(training_model).to be_present
          expect(retraining_run.reload).to be_failed
        end

        it "logs all metrics" do
          retraining_job.update(auto_deploy: true)

          setup_evaluation([1, 2, 3], [1, 2, 3])
          original_model = EasyML::Model.find_by(name: model.name).latest_snapshot
          expect(retraining_run.perform_retraining!).to be true

          expect(EasyML::DeployWorker.jobs.count).to eq 1
          Sidekiq::Worker.drain_all

          original_model.reload
          expect(original_model).to be_retired

          trained_model = EasyML::Model.find_by(name: model.name).latest_snapshot
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
        end

        it "uses custom evaluator for promotion decision" do
          retraining_job.update(auto_deploy: true)
          model.update(metrics: model.metrics + [:custom])

          original_model = model.latest_snapshot

          setup_evaluation([1, 2, 3], [2000, 3000, 4000])

          expect(retraining_run.perform_retraining!).to be true
          Sidekiq::Worker.drain_all

          expect(retraining_run.metric_value).to eq 8994.0
          expect(retraining_run.threshold).to eq 1_000
          expect(retraining_run.threshold_direction).to eq "maximize"
          expect(retraining_run.deployable).to eq true
          expect(retraining_run).to be_success
          expect(original_model.reload).to be_retired

          trained_model = EasyML::Model.find_by(name: model.name).latest_snapshot
          expect(trained_model.id).to_not eq original_model.id
          expect(trained_model.retraining_runs.first).to eq retraining_run

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

          allow(retraining_run).to receive(:should_tune?).and_return(true)
          setup_evaluation([1, 2, 3], [1, 2, 3], true)
          m = EasyML::Model.find_by(name: model.name).latest_snapshot
          m.callbacks = []
          expect(retraining_run.perform_retraining!).to be true

          expect(retraining_run.metadata["wandb_url"]).to eq "https://wandb.ai"
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
