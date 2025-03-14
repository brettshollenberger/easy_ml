module EasyML
  class PredictionsController < ApplicationController
    skip_before_action :verify_authenticity_token, only: [:create]

    def create
      slug = params[:model]
      model = EasyML::Model.find_by(slug: slug)
      unless model.present?
        return render json: { error: "Model not found" }, status: :not_found
      end

      unless model.inference_version.present?
        return render json: { error: "Model not found" }, status: :not_found
      end

      unless params.key?(:input)
        return render json: { error: "Must provide key: input" }, status: :unprocessable_entity
      end
      input = params[:input].permit!.to_h

      unless input.is_a?(Hash)
        return render json: { error: "Input must be a hash" }, status: :unprocessable_entity
      end

      valid, fields = EasyML::Predict.validate_input(slug, input)
      unless valid
        return render json: { error: "Missing required fields: #{fields}" }, status: :unprocessable_entity
      end

      type = (params[:type] || :predict).to_sym
      allowed_types = [:predict, :predict_proba]
      unless allowed_types.include?(type)
        return render json: { error: "Invalid type: #{type}" }, status: :not_found
      end

      prediction = EasyML::Predict.send(type, slug, input)

      render json: { prediction: EasyML::PredictionSerializer.new(prediction).serializable_hash.dig(:data, :attributes) }, status: :ok
    rescue ActiveRecord::RecordNotFound
      render json: { prediction: EasyML::PredictionSerializer.new(prediction).serializable_hash.dig(:data, :attributes) }, status: :ok
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Model not found" }, status: :not_found
    rescue => e
      EasyML::ErrorLogger.error(e)
      render json: { error: "Internal server error" }, status: 500
    end
  end
end
