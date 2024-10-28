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

    def self.fork(model_name)
      instance.fork(model_name)
    end

    def predict(model_name, df)
      ensure_model_loaded(model_name)
      models[model_name].predict(df)
    end

    def fork(model_name)
      # First try to find existing training model
      training_model = EasyML::Model.find_by(name: model_name, status: :training)
      return training_model if training_model.present?

      # If no training model exists, fork the inference model
      inference_model = EasyML::Model.find_by!(name: model_name, status: :inference)
      inference_model.fork
    end

    private

    def ensure_model_loaded(model_name)
      current_model = EasyML::Model.find_by!(name: model_name, status: :inference)

      # Load new model if not loaded or different version
      model_not_loaded = models[model_name].nil?
      model_is_new_model = models[model_name]&.id != current_model&.id
      return unless model_not_loaded || model_is_new_model

      models[model_name] = current_model
    end
  end
end
