require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::Orchestrator do
  include ModelSpecHelper
  let(:datasource) do
    EasyML::Datasource.create(
      name: "Polars Datasource",
      datasource_type: "polars",
      df: df
    )
  end

  after(:all) do
    EasyML::Cleaner.clean
  end

  before(:each) do
    EasyML::Orchestrator.reset
  end

  let(:model) do
    pretrain_loans_model
  end

  describe ".predict" do
    it "loads model and makes predictions" do
      model.promote

      df, = model.dataset.test(split_ys: true)
      model_preds = model.predict(df)

      orch_preds = described_class.predict(model.name, df)
      expect(orch_preds).to eq model_preds
      expect(model_preds.length).to eq(df.length)
    end

    it "doesn't reload the model when model already loaded" do
      model.promote

      df, = model.dataset.test(split_ys: true)
      expect_any_instance_of(EasyML::Models::XGBoost).to receive(:initialize_model).once.and_call_original

      3.times do
        described_class.predict(model.name, df)
      end
    end

    it "does reload the model when inference model changes" do
      model.promote
      df, = model.dataset.test(split_ys: true)

      # Orchestrator already ran model loading her
      3.times do
        described_class.predict(model.name, df)
      end

      expect(model).to_not be_promotable
      expect(model.cannot_promote_reasons).to include("Model has not changed")

      randomize_hypers(model)
      expect(model).to_not be_promotable
      model.fit
      expect(model).to be_promotable

      old_preds = model.latest_snapshot.predict(df)
      new_preds = model.predict(df)
      expect(old_preds).to_not eq new_preds

      model.promote

      # So if Orchestrator runs model loading again here, test passes
      expect_any_instance_of(EasyML::Models::XGBoost).to receive(:initialize_model).once.and_call_original
      3.times do
        described_class.predict(model.name, df)
      end
    end

    it "raises error for non-existent model" do
      expect do
        described_class.predict("non_existent_model", model.dataset.test(split_ys: true).first)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe ".train" do
    it "trains the latest model" do
      model.promote

      randomize_hypers(model)
      model.save

      x_train, y_train = model.dataset.train(split_ys: true)
      y_train["rev"] = Polars::Series.new(Array.new(5) { 10_000 })
      allow_any_instance_of(EasyML::Dataset).to receive(:train).and_return([x_train, y_train])

      training_model = described_class.train(model.name)
      expect(training_model.status).to eq "training"
      expect(training_model.is_fit?).to be true
      expect(training_model).to be_promotable
      expect(training_model.name).to eq model.name
      expect(training_model.version).to_not eq model.version
    end

    it "uses existing training model if one exists" do
      model.model_file = model_file
      model.version = model_file.filename.gsub(/\.json/, "")
      model.save
      model.promote

      # Create a training model
      training_model = model.fork
      expect(training_model.status).to eq "training"

      # Train should use existing training model
      trained_model = described_class.train(model.name)
      expect(trained_model).to eq training_model
      expect(trained_model.fit?).to be true
    end

    it "accepts a tuner for hyperparameter optimization" do
      model.model_file = model_file
      model.version = model_file.filename.gsub(/\.json/, "")
      model.save
      model.promote

      tuner = {
        n_trials: 5,
        objective: :mean_absolute_error,
        config: {
          learning_rate: { min: 0.01, max: 0.1 },
          n_estimators: { min: 1, max: 2 },
          max_depth: { min: 1, max: 5 }
        }
      }

      expect_any_instance_of(EasyML::Core::Tuner).to receive(:tune).and_return({
                                                                                 "learning_rate" => 0.05,
                                                                                 "n_estimators" => 2,
                                                                                 "max_depth" => 3
                                                                               })

      training_model = described_class.train(model.name, tuner: tuner)
      expect(training_model.status).to eq "training"
      expect(training_model.fit?).to be true
      expect(training_model.hyperparameters["learning_rate"]).to eq 0.05
      expect(training_model.hyperparameters["n_estimators"]).to eq 2
      expect(training_model.hyperparameters["max_depth"]).to eq 3

      model.model_file.cleanup([model.model_file.full_path]) # Keep only the original file
    end

    it "raises error for non-existent model" do
      expect do
        described_class.train("non_existent_model")
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "raises error when trying to train an inference model directly" do
      model.model_file = model_file
      model.version = model_file.filename.gsub(/\.json/, "")
      model.save
      model.promote

      expect do
        model.fit
      end.to raise_error(RuntimeError, /Cannot train inference model/)
    end

    it "accepts tuner configuration for hyperparameter optimization" do
      model.model_file = model_file
      model.version = model_file.filename.gsub(/\.json/, "")
      model.save
      model.promote

      tuner = {
        n_trials: 5,
        objective: :mean_absolute_error,
        config: {
          learning_rate: { min: 0.01, max: 0.1 },
          n_estimators: { min: 1, max: 2 },
          max_depth: { min: 1, max: 5 }
        }
      }

      # Expect the tuner to be created with the config
      expect(EasyML::Core::Tuner).to receive(:new).with(tuner).and_call_original
      # Expect tune to be called and return some parameters
      expect_any_instance_of(EasyML::Core::Tuner).to receive(:tune).and_return({
                                                                                 "learning_rate" => 0.05,
                                                                                 "n_estimators" => 2,
                                                                                 "max_depth" => 3
                                                                               })

      training_model = described_class.train(model.name, tuner: tuner)
      expect(training_model.status).to eq "training"
      expect(training_model.fit?).to be true
      expect(training_model.hyperparameters["learning_rate"]).to eq 0.05
      expect(training_model.hyperparameters["n_estimators"]).to eq 2
      expect(training_model.hyperparameters["max_depth"]).to eq 3

      model.model_file.cleanup([model.model_file.full_path]) # Keep only the original file
    end
  end
end
