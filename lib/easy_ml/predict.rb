require "singleton"

module EasyML
  class Predict
    include Singleton

    attr_reader :models

    def initialize
      @models = {}
    end

    def self.predict(model_name, df)
      if df.is_a?(Hash)
        df = Polars::DataFrame.new(df)
      end
      raw_input = df.to_hashes&.first
      df = instance.normalize(model_name, df)
      preds = instance.predict(model_name, df)
      current_version = instance.get_model(model_name)

      EasyML::Prediction.create!(
        model: current_version.model,
        model_history: current_version,
        prediction_type: current_version.model.task,
        prediction_value: {
          value: preds.first,
        }.compact,
        raw_input: raw_input,
        normalized_input: df.to_hashes&.first,
      )

      preds
    end

    def self.train(model_name, tuner: nil, evaluator: nil)
      instance.train(model_name, tuner: tuner, evaluator: evaluator)
    end

    def predict(model_name, df)
      get_model(model_name).predict(df)
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
      current_model = EasyML::Model.find_by!(name: model_name).inference_version

      # Load new model if not loaded or different version
      model_not_loaded = models[model_name].nil?
      model_is_new_version = models[model_name]&.id != current_model&.id
      return unless model_not_loaded || model_is_new_version

      models[model_name] = current_model
    end
  end
end
