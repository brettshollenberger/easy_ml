require "singleton"

module EasyML
  class Predict
    include Singleton
    include EasyML::Timing

    attr_reader :models

    def initialize
      @models = {}
    end

    def self.normalize_input(df)
      if df.is_a?(Hash)
        df = Polars::DataFrame.new(df)
      end
      df
    end

    def self.predict(model_name, df, serialize: false)
      df = normalize_input(df)
      output = make_predictions(model_name, df) do |model, normalized_df|
        model.predict(normalized_df, normalized: true)
      end

      if serialize
        EasyML::PredictionSerializer.new(output).serializable_hash
      else
        output
      end
    end
    measure_method_timing :predict

    def self.predict_proba(model_name, df, serialize: false)
      df = normalize_input(df)
      output = make_predictions(model_name, df) do |model, normalized_df|
        probas = model.predict_proba(normalized_df, normalized: true)
        probas.map { |proba_array| proba_array.map { |p| p.round(4) } }
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

    def predict_proba(model_name, df)
      get_model(model_name).predict_proba(df)
    end

    def self.validate_input(model_name, df)
      df = normalize_input(df)
      instance.get_model(model_name).dataset.validate_input(df)
    end

    def normalize(model_name, df)
      get_model(model_name).dataset.normalize(df, inference: true)
    end
    measure_method_timing :normalize

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

    def self.make_predictions(model_name, df)
      raw_input = df.to_hashes
      normalized_df = instance.normalize(model_name, df)
      normalized_input = normalized_df.to_hashes
      current_version = instance.get_model(model_name)

      predictions = yield(current_version, normalized_df)
      proba = predictions.is_a?(Array) ? predictions : nil

      output = predictions.zip(raw_input, normalized_input).map do |pred, raw, norm|
        EasyML::Prediction.create!(
          model_id: current_version.model.id,
          model_history_id: current_version.id,
          prediction_type: current_version.model.task,
          prediction_value: pred,
          raw_input: raw,
          normalized_input: norm,
          metadata: proba ? { probabilities: pred } : {},
        )
      end

      output.count == 1 ? output.first : output
    end
    measure_method_timing :make_predictions

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
