module EasyML
  class PredictionsController < ApplicationController
    skip_before_action :verify_authenticity_token, only: [:create]

    def create
      model_name = params[:model]
      input = params[:input]

      predictions = EasyML::Predict.predict(model_name, input)

      render json: { prediction: predictions.first }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Model not found" }, status: :not_found
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
