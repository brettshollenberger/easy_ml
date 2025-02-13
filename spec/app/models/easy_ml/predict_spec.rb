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

      # Predict already ran model loading her
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
end
