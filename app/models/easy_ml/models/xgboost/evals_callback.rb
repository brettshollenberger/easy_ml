module EasyML
  module Models
    class XGBoost
      class EvalsCallback < ::XGBoost::TrainingCallback
        attr_accessor :started_at, :preprocessed

        def initialize(options)
          @preprocessed = nil
        end

        attr_reader :model, :tuner

        def model=(model)
          @model = model
        end

        def prepare_callback(tuner)
          @tuner = tuner
        end

        def as_json
          { callback_type: :evals_callback }
        end

        def wandb_enabled?
          EasyML::Configuration.wandb_api_key.present?
        end

        def before_iteration(*args)
          return false unless wandb_enabled?

          false
        end

        def valid_dataset
          if tuner.present?
            [tuner.x_valid, tuner.y_valid]
          else
            model.dataset.valid(split_ys: true)
          end
        end

        def after_iteration(booster, epoch, history)
          return false unless wandb_enabled?

          log_frequency = 10
          if epoch % log_frequency == 0
            model.adapter.external_model = booster
            x_valid, y_valid = valid_dataset
            @preprocessed ||= model.preprocess(x_valid)
            y_pred = model.predict(@preprocessed)
            dataset = model.dataset.valid(all_columns: true)

            metrics = model.evaluate(y_pred: y_pred, y_true: y_valid, x_true: x_valid, dataset: dataset)
            Wandb.log(metrics)
          end

          false
        end

        def before_training(booster)
          return booster unless wandb_enabled?

          booster
        end

        def after_training(booster)
          return booster unless wandb_enabled?

          if model.last_run.present? && model.last_run&.wandb_url.nil?
            if tuner.present? && !tuner.current_run.wandb_url.present?
              tuner.current_run.wandb_url = Wandb.current_run.url
            end
            base_url = Wandb.current_run.url.split("/runs").first
            model.last_run.update(wandb_url: base_url)
          end

          track_feature_importance(booster)
          if tuner.nil?
            track_cumulative_feature_importance(false)
          end

          booster
        end

        def track_feature_importance(booster)
          fi = booster.score(importance_type: "gain")

          # Convert all keys to strings immediately to avoid byte string issues
          fi = fi.transform_keys(&:to_s)

          # Store feature importance values for this run
          @feature_importances ||= {}
          fi.each do |feature, importance|
            @feature_importances[feature] ||= { sum: 0.0, count: 0 }
            @feature_importances[feature][:sum] += importance
            @feature_importances[feature][:count] += 1
          end
        end

        def wandb_callback
          model.callbacks.detect { |cb| cb.class == Wandb::XGBoostCallback }
        end

        def track_cumulative_feature_importance(finish = true)
          return unless @feature_importances

          project_name = model.adapter.get_wandb_project
          Wandb.login(api_key: EasyML::Configuration.wandb_api_key)
          Wandb.init(project: project_name)

          # Calculate running averages
          avg_importances = @feature_importances.transform_values do |stats|
            stats[:sum] / stats[:count]
          end

          # Create table data with running averages
          fi_data = avg_importances.map { |feature, importance| [feature, importance] }

          # Use a consistent table and plot for updates
          table = Wandb::Table.new(data: fi_data, columns: %w[Feature Importance])
          bar_plot = Wandb::Plot.bar(table.table, label: "Feature", value: "Importance", title: "Feature Importance (Across All Runs)")

          # Convert all values to basic Ruby types that can be serialized to JSON
          log_data = {
            "feature_importance" => bar_plot.__pyptr__,
          }
          Wandb.log(log_data)
          model.adapter.delete_wandb_project if finish
          Wandb.finish if finish
        end

        def after_tuning
          track_cumulative_feature_importance
        end
      end
    end
  end
end
