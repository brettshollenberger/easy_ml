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
    model_config[:name] = model_name
    model_config[:task] = "regression"
    model_config[:callbacks] = [
      { wandb: { project_name: "Fancy Project" } }
    ]
    EasyML::Model.create(**loans_model_config).tap do |model|
      model.fit
      model.promote
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
      model: model.name,
      frequency: "day",
      at: 2,
      active: true,
      evaluator: {
        metric: :root_mean_squared_error,
        max: 1000
      },
      tuner_config: {
        n_trials: 5,
        objective: :mean_absolute_error,
        config: {
          learning_rate: { min: 0.01, max: 0.1 },
          n_estimators: { min: 1, max: 2 },
          max_depth: { min: 1, max: 5 }
        }
      }
    )
  end

  let(:retraining_run) do
    described_class.create!(
      retraining_job: retraining_job,
      status: "pending"
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

      it "doesn't update model if model has not changed" do
        allow(retraining_job).to receive(:should_tune?).and_return(false)

        expect(EasyML::Orchestrator).to receive(:train)
          .with(model.name, evaluator: retraining_job.evaluator)
          .and_call_original

        expect(retraining_run.perform_retraining!).to be true
        expect(retraining_run.reload.error_message).to eq "Model has not changed"
      end
    end

    it "handles errors during retraining" do
      allow(EasyML::Orchestrator).to receive(:train).and_raise("Test error")

      expect(retraining_run.perform_retraining!).to be false
      expect(retraining_run.reload).to be_failed
      expect(retraining_run.error_message).to eq("Test error")
    end

    it "doesn't perform retraining if not pending" do
      retraining_run.update!(status: "completed")
      expect(retraining_run.perform_retraining!).to be false
    end

    context "with model evaluation" do
      def setup_evaluation(y_pred, y_true, call_original = false)
        # Only stub train to avoid the actual training process
        a = allow(EasyML::Orchestrator).to receive(:train) do |model_name|
          training_model = EasyML::Model.find_by(name: model_name)

          # Set up our test expectations on the forked model
          allow(training_model).to receive_message_chain(:dataset, :refresh).and_return(true)
          allow(training_model).to receive_message_chain(:dataset, :target, :present?).and_return(true)
          allow(training_model).to receive_message_chain(:dataset, :datasource, :in_memory?).and_return(false)
          allow(training_model).to receive_message_chain(:dataset, :lock).and_return(true)
          allow(training_model).to receive_message_chain(:dataset, :test)
            .and_return([[1, 2, 3], y_true])
          allow(training_model).to receive(:predict).and_return(y_pred)
          allow(training_model).to receive(:promotable?).and_return(true)
          allow(training_model).to receive(:cannot_promote_reasons).and_return([])
          allow(training_model).to receive(:reload).and_return(training_model)
          allow(training_model).to receive_message_chain(:dataset, :reload).and_return(training_model)
          allow(training_model).to receive_message_chain(:bump_versions).and_call_original
          allow(training_model).to receive_message_chain(:dataset, :bump_versions).with(any_args).and_return(true)
          allow(training_model).to receive_message_chain(:save).and_call_original
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

          def evaluate(y_pred:, y_true:, x_true:)
            # Simple custom metric for testing
            (y_pred.sum - y_true.sum).abs
          end
        end
      end

      before do
        # Register the custom evaluator
        EasyML::Core::ModelEvaluator.register(:custom, custom_evaluator)
      end

      context "with basic evaluator" do
        before do
          retraining_job.update!(
            evaluator: {
              metric: :root_mean_squared_error,
              max: 100
            }
          )
        end

        it "promotes model when RMSE is below threshold" do
          setup_evaluation([1, 2, 3], [1, 2, 3])
          original_model = EasyML::Model.find_by(name: model.name).latest_snapshot
          expect(retraining_run.perform_retraining!).to be true

          original_model.reload
          expect(original_model).to be_retired

          trained_model = EasyML::Model.find_by(name: model.name).latest_snapshot
          expect(trained_model).to be_present
          expect(trained_model.id).to_not eq original_model.id
          expect(trained_model).to be_inference # after promotion
          expect(trained_model.retraining_runs.first).to eq retraining_run
          expect(retraining_run.reload).to be_completed
        end

        it "does not promote model when RMSE is above threshold" do
          setup_evaluation([1, 2, 3], [100, 200, 300])
          original_model = EasyML::Model.find_by(name: model.name).latest_snapshot
          expect(retraining_run.perform_retraining!).to be true

          original_model.reload
          expect(original_model).to_not be_retired

          training_model = EasyML::Model.where(name: model.name)
          expect(training_model).to be_present
          expect(retraining_run.reload).to be_failed
        end
      end

      context "with custom evaluator" do
        before do
          retraining_job.update!(
            evaluator: {
              metric: :custom,
              max: 1000
            }
          )
        end

        it "uses custom evaluator for promotion decision" do
          setup_evaluation([1, 2, 3], [2, 3, 4])

          original_model = EasyML::ModelHistory.find_by(name: model.name)
          expect(retraining_run.perform_retraining!).to be true
          expect(retraining_run.metric_value).to eq 3.0
          expect(retraining_run.threshold).to eq 1_000
          expect(retraining_run.threshold_direction).to eq "max"
          expect(retraining_run.should_promote).to eq true
          expect(retraining_run).to be_completed
          expect(original_model.reload).to be_retired

          trained_model = EasyML::Model.find_by(name: model.name).latest_snapshot
          expect(trained_model.id).to_not eq original_model.id
          expect(trained_model.retraining_runs.first).to eq retraining_run
        end
      end

      context "With callbacks" do
        it "passes metadata from the tuner to the retraining_run" do
          allow(retraining_run).to receive(:should_tune?).and_return(true)
          setup_evaluation([1, 2, 3], [1, 2, 3], true)
          m = EasyML::Model.find_by(name: model.name).latest_snapshot
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
      expect(run).not_to be_completed

      run.status = "completed"
      expect(run).to be_completed
      expect(run).not_to be_pending

      run.status = "failed"
      expect(run).to be_failed
      expect(run).not_to be_completed

      run.status = "running"
      expect(run).to be_running
      expect(run).not_to be_completed
    end
  end
end
