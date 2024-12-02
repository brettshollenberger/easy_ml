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

  let(:model) do
    model_config[:name] = "My Model"
    model_config[:task] = "regression"
    EasyML::Model.create(**model_config)
  end

  describe ".predict" do
    it "loads model and makes predictions" do
      model.model_file = model_file
      model.version = model_file.filename.gsub(/\.json/, "")
      model.save
      model.promote

      df, = model.dataset.test(split_ys: true)
      model_preds = model.predict(df)

      orch_preds = described_class.predict(model.name, df)
      expect(orch_preds).to eq model_preds
      expect(model_preds.length).to eq(df.length)
    end

    it "doesn't reload the model when model already loaded" do
      expect_any_instance_of(EasyML::Core::Models::XGBoost).to receive(:load).once.and_call_original

      model.model_file = model_file
      model.version = model_file.filename.gsub(/\.json/, "")
      model.save
      model.promote
      df, = model.dataset.test(split_ys: true)

      3.times do
        described_class.predict(model.name, df)
      end
    end

    it "does reload the model when inference model changes" do
      model.model_file = model_file
      model.version = model_file.filename.gsub(/\.json/, "")
      orig_path = model.model_file.full_path
      model.save
      model.promote
      df, = model.dataset.test(split_ys: true)

      allow_any_instance_of(EasyML::ModelFile).to receive(:cleanup).and_return(true)

      3.times do
        described_class.predict(model.name, df)
      end

      model2 = model.fork
      expect(model2.promotable?).to be_falsey
      expect { model2.promote }.to raise_error "Cannot promote: Model has not been trained"
      model2.fit
      model2.save
      expect(model2.promotable?).to eq true
      model2.promote

      expect_any_instance_of(EasyML::Core::Models::XGBoost).to receive(:load).once.and_call_original
      3.times do
        described_class.predict(model.name, df)
      end
      allow_any_instance_of(EasyML::ModelFile).to receive(:cleanup).and_call_original
      model2.model_file.cleanup([orig_path]) # Keep only the original file
      expect(Dir.glob(File.join(Pathname.new(orig_path).dirname, "**/*.json")).count).to eq 1
    end

    it "raises error for non-existent model" do
      expect do
        described_class.predict("non_existent_model", model.dataset.test(split_ys: true).first)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe ".fork" do
    it "returns existing training model if one exists" do
      # Create and promote first model
      model.model_file = model_file
      model.version = model_file.filename.gsub(/\.json/, "")
      model.save
      model.promote

      # Create a training model
      training_model = model.fork
      expect(training_model.status).to eq "training"

      # Fork should return existing training model
      forked = described_class.fork(model.name)
      expect(forked).to eq training_model
      model.model_file.cleanup([model.model_file.full_path]) # Keep only the original file
    end

    it "forks inference model if no training model exists" do
      Timecop.freeze(EasyML::Support::EST.now)
      model.model_file = model_file
      model.version = model_file.filename.gsub(/\.json/, "")
      model.save
      model.promote

      Timecop.freeze(EasyML::Support::EST.now + 3.minutes)
      forked = described_class.fork(model.name)
      expect(forked.status).to eq "training"
      expect(forked.name).to eq model.name
      expect(forked.version).not_to eq model.version

      Timecop.return
      model.model_file.cleanup([model.model_file.full_path]) # Keep only the original file
    end

    it "raises error for non-existent model" do
      expect do
        described_class.fork("non_existent_model")
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe ".train" do
    it "trains a forked model" do
      model.model_file = model_file
      model.version = model_file.filename.gsub(/\.json/, "")
      model.save
      model.promote

      training_model = described_class.train(model.name)
      expect(training_model.status).to eq "training"
      expect(training_model.fit?).to be true
      expect(training_model.name).to eq model.name
      expect(training_model.version).not_to eq model.version
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
