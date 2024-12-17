require "singleton"

module EasyML
  class Orchestrator
    include Singleton

    attr_reader :models

    def initialize
      @models = {}
    end

    def self.predict(model_name, df)
      instance.predict(model_name, df)
    end

    def self.train(model_name, tuner: nil, evaluator: nil)
      instance.train(model_name, tuner: tuner, evaluator: evaluator)
    end

    def predict(model_name, df)
      load_model(model_name)
      models[model_name].predict(df)
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
