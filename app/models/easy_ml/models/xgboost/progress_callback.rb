module EasyML
  module Models
    class XGBoost
      class ProgressCallback < ::XGBoost::TrainingCallback
        def initialize(options)
        end

        def as_json
          { callback_type: :progress_callback }
        end

        def before_iteration(*args)
          false
        end

        attr_reader :model

        def model=(model)
          @model = model
        end

        def after_iteration(booster, epoch, history)
          if model.adapter.progress_callback
            model.adapter.progress_callback.call({ iteration: epoch, evals: history })
          end
          return false
        end

        def before_training(booster)
          booster
        end

        def after_training(booster)
          booster
        end
      end
    end
  end
end
