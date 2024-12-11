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

    def train(model_name, tuner: nil, evaluator: nil)
      training_model = EasyML::Model.find_by(name: model_name)
      raise ActiveRecord::RecordNotFound if training_model.nil?

      tuner = tuner.symbolize_keys if tuner.present?
      best_params = nil

      if tuner
        # Create tuner from config
        tuner.merge!(evaluator: evaluator) if evaluator.present?
        tuner_instance = EasyML::Core::Tuner.new(tuner)

        # Configure tuner with model and dataset
        tuner_instance.model = training_model
        adapter = case tuner_instance.model.model_type.to_sym
          when :xgboost
            EasyML::Core::Tuner::Adapters::XGBoostAdapter.new
          end
        tuner_instance.adapter = adapter
        tuner_instance.dataset = training_model.dataset

        # Run hyperparameter optimization
        best_params = tuner_instance.tune

        # Update model configuration with best parameters
        best_params.each do |key, value|
          training_model.hyperparameters[key] = value
        end
      end

      training_model.evaluator = evaluator if evaluator.present?
      training_model.fit
      training_model.save
      return training_model, best_params
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
