require "spec_helper"
require "support/model_spec_helper"

RSpec.describe "Predictions API", type: :request do
  include ModelSpecHelper

  let(:model) { titanic_model }

  before(:each) do
    EasyML::Predict.reset
    EasyML::Cleaner.clean
  end

  after(:each) do
    EasyML::Predict.reset
    EasyML::Cleaner.clean
  end

  def setup(model)
    mock_s3_upload
    model.save
    model.unlock!
    model.train(async: false)
    expect(model).to be_deployable
    model.deploy(async: false)
  end

  describe "POST /easy_ml/predictions" do
    it "makes predictions using a trained and deployed model" do
      # Train and deploy the model
      setup(model)

      # Get test data
      df, = model.dataset.test(split_ys: true)
      expected_predictions = model.predict(df)

      # Make prediction request
      instance = df[0].to_hashes[0]
      post "/easy_ml/predictions", params: { model: model.slug, input: instance }
      
      expect(response).to have_http_status(:ok)
      
      prediction = JSON.parse(response.body).dig("prediction")
      expect(prediction.dig("prediction")).to be_between(0,1)
    end

    it "makes predictions using a trained and deployed model" do
      # Train and deploy the model
      setup(model)

      # Make prediction request
      instance = {
        "Sex": "something else",
        "Fare": 100,
        "Parch": 1,
        "SibSp": 1,
        "Pclass": 1,
        "PassengerId": 200,
      }
      post "/easy_ml/predictions", params: { model: model.slug, input: instance }
      
      expect(response).to have_http_status(:ok)
      
      normalized_input = JSON.parse(response.body).dig("prediction", "normalized_input")
      expect(normalized_input.dig("Sex_other")).to eq true
      expect(normalized_input.dig("Embarked_other")).to eq true
    end

    it "returns 404 for non-existent model" do
      post "/easy_ml/predictions", params: { model: "non_existent_model", input: {} }
      expect(response).to have_http_status(:not_found)
    end

    it "returns 422 for invalid input data" do

      post "/easy_ml/predictions", params: { model: model.slug, input: {} }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /easy_ml/predictions predict proba" do
    it "makes probability predictions using a trained and deployed model" do
      # Train and deploy the model
      setup(model)

      # Get test data
      df, = model.dataset.test(split_ys: true)
      expected_probas = model.predict_proba(df).map do |proba|
        proba.map { |p| p.round(4) }
      end

      # Make prediction request
      input = df[0].to_hashes[0]
      post "/easy_ml/predictions", params: { model: model.slug, input: input, type: "predict_proba" }
      
      expect(response).to have_http_status(:ok)
      
      prediction = JSON.parse(response.body).dig("prediction")
      expect(prediction.dig("prediction")[0]).to be_between(0, 1)
      expect(prediction.dig("prediction")[1]).to be_between(0, 1)
    end
  end
end
