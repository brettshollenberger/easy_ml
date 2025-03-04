require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::Predict do
  include ModelSpecHelper
  before(:each) do
    EasyML::Predict.reset
  end

  after(:each) do
    EasyML::Predict.reset
  end

  let(:model) do
    titanic_model
  end

  describe ".predict" do
    it "loads model and makes predictions" do
      mock_s3_upload

      model.save
      model.train(async: false)
      model.deploy(async: false)
      expect(model.weights).to eq(model.inference_version.weights)

      df, = model.dataset.test(split_ys: true)
      model_preds = model.predict(df)
      expect(model.predict(df)).to eq(model.inference_version.predict(df))

      live_preds = described_class.predict(model.slug, df)
      expect(live_preds.map(&:prediction_value)).to eq model_preds
      expect(model_preds.length).to eq(df.length)
    end

    it "doesn't reload the model when model already loaded" do
      mock_s3_upload

      model.save
      model.train(async: false)
      model.deploy(async: false)

      df, = model.dataset.test(split_ys: true)
      expect_any_instance_of(EasyML::Models::XGBoost).to receive(:initialize_model).once.and_call_original

      3.times do
        described_class.predict(model.slug, df)
      end
    end

    it "does reload the model when inference model changes" do
      mock_s3_upload

      model.hyperparameters.n_estimators = 1
      model.save
      model.train(async: false)
      model.deploy(async: false)
      df, = model.dataset.test(split_ys: true)

      # Predict already ran model loading here
      3.times do
        described_class.predict(model.slug, df)
      end

      Timecop.freeze(2.hours.from_now)

      randomize_hypers(model)
      model.hyperparameters.n_estimators = 100
      model.save
      model.train(async: false)
      expect(model).to be_deployable

      old_preds = model.current_version.predict(df)
      new_preds = model.predict(df)
      expect(old_preds).to_not eq new_preds

      model.deploy(async: false)

      # So if Predict runs model loading again here, test passes
      expect_any_instance_of(EasyML::Models::XGBoost).to receive(:initialize_model).once.and_call_original
      3.times do
        described_class.predict(model.slug, df)
      end
    end

    it "raises error for non-existent model" do
      expect do
        described_class.predict("non_existent_model", model.dataset.test(split_ys: true).first)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe ".predict_proba" do
    it "loads model and makes probability predictions" do
      mock_s3_upload

      model.save
      model.train(async: false)
      model.deploy(async: false)
      expect(model.weights).to eq(model.inference_version.weights)

      df, = model.dataset.test(split_ys: true)
      model_probas = model.predict_proba(df).map do |proba|
        proba.map { |p| p.round(4) }
      end
      expect(model.predict_proba(df)).to eq(model.inference_version.predict_proba(df))

      live_probas = described_class.predict_proba(model.slug, df)
      expect(live_probas.map(&:probabilities)).to eq model_probas
      expect(model_probas.length).to eq(df.length)

      # Verify probabilities are valid
      model_probas.each do |proba|
        expect(proba).to be_a(Array)
        expect(proba.length).to eq(2) # Binary classification
        expect(proba.sum).to be_within(0.0001).of(1.0) # Probabilities sum to 1
        expect(proba).to all(be_between(0, 1)) # Valid probabilities
      end

      # Verify predictions are recorded in database
      predictions = EasyML::Prediction.joins(:model).where("easy_ml_models.slug = ?", model.slug).last(df.length)
      expect(predictions.map { |p| p.metadata["probabilities"] }).to eq(model_probas)
    end

    it "doesn't reload the model when model already loaded" do
      mock_s3_upload

      model.save
      model.train(async: false)
      model.deploy(async: false)

      df, = model.dataset.test(split_ys: true)
      expect_any_instance_of(EasyML::Models::XGBoost).to receive(:initialize_model).once.and_call_original

      3.times do
        described_class.predict_proba(model.slug, df)
      end
    end

    it "raises error for non-existent model" do
      expect do
        described_class.predict_proba("non_existent_model", model.dataset.test(split_ys: true).first)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
