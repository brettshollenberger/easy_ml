module EasyML
  class PredictionsController < ApplicationController
    skip_before_action :verify_authenticity_token, only: [:create]

    def create
      unless params.key?(:input)
        return render json: { error: "Must provide key: input" }, status: :not_found
      end
      input = params[:input].permit!.to_h

      unless input.is_a?(Hash)
        return render json: { error: "Input must be a hash" }, status: :not_found
      end

      model_name = params[:model]
      unless EasyML::Model.find_by(name: model_name).present?
        return render json: { error: "Model not found" }, status: :not_found
      end

      prediction = EasyML::Predict.predict(model_name, input)

      render json: { prediction: EasyML::PredictionSerializer.new(prediction).serializable_hash.dig(:data, :attributes) }, status: :ok
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Model not found" }, status: :not_found
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
