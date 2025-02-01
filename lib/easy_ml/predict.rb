require "singleton"

module EasyML
  class Predict
    include Singleton

    attr_reader :models

    def initialize
      @models = {}
    end

    def self.predict(model_name, df, serialize: false)
      if df.is_a?(Hash)
        df = Polars::DataFrame.new(df)
      end
      raw_input = df.to_hashes
      df = instance.validate_input(model_name, df)
      begin
        df = instance.normalize(model_name, df)
      rescue => e
        binding.pry
      end
      normalized_input = df.to_hashes
      preds = instance.predict(model_name, df)
      current_version = instance.get_model(model_name)

      output = preds.zip(raw_input, normalized_input).map do |pred, raw, norm|
        EasyML::Prediction.create!(
          model: current_version.model,
          model_history: current_version,
          prediction_type: current_version.model.task,
          prediction_value: pred,
          raw_input: raw,
          normalized_input: norm,
        )
      end

      output = if output.is_a?(Array) && output.count == 1
          output.first
        else
          output
        end

      if serialize
        EasyML::PredictionSerializer.new(output).serializable_hash
      else
        output
      end
    end

    def self.train(model_name, tuner: nil, evaluator: nil)
      instance.train(model_name, tuner: tuner, evaluator: evaluator)
    end

    def predict(model_name, df)
      get_model(model_name).predict(df)
    end

    def validate_input(model_name, df)
      get_model(model_name).dataset.validate_input(df)
    end

    def normalize(model_name, df)
      get_model(model_name).dataset.normalize(df, inference: true)
    end

    def get_model(model_name)
      load_model(model_name)
      models[model_name]
    end

    def reset
      @models = {}
    end

    def self.reset
      instance.reset
    end

    private

    def load_model(model_name)
      current_model = EasyML::Model.find_by!(slug: model_name).inference_version

      # Load new model if not loaded or different version
      model_not_loaded = models[model_name].nil?
      model_is_new_version = models[model_name]&.id != current_model&.id
      return unless model_not_loaded || model_is_new_version

      models[model_name] = current_model
    end
  end
end
