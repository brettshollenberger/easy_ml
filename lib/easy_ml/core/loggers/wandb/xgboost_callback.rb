module EasyML
  module Loggers
    module Wandb
      class XGBoostCallback
        MINIMIZE_METRICS = %w[rmse logloss error] # Add other metrics as needed
        MAXIMIZE_METRICS = %w[auc accuracy] # Add other metrics as needed

        def initialize(log_model: false, log_feature_importance: true, importance_type: "gain", define_metric: true)
          @log_model = log_model
          @log_feature_importance = log_feature_importance
          @importance_type = importance_type
          @define_metric = define_metric

          return if EasyML::Loggers::Wandb.current_run

          raise "You must call wandb.init() before WandbCallback()"
        end

        def before_training(model:)
          # Update Wandb config with model configuration
          EasyML::Loggers::Wandb.current_run.config = model.params
          EasyML::Loggers::Wandb.log(model.params)
        end

        def after_training(model:)
          # Log the model as an artifact
          log_model_as_artifact(model) if @log_model

          # Log feature importance
          log_feature_importance(model) if @log_feature_importance

          # Log best score and best iteration
          return unless model.best_score

          EasyML::Loggers::Wandb.log(
            "best_score" => model.best_score.to_f,
            "best_iteration" => model.best_iteration.to_i
          )
        end

        def before_iteration(model:, epoch:, evals:)
          # noop
        end

        def after_iteration(model:, epoch:, evals:, res:)
          res.each do |metric_name, value|
            data, metric = metric_name.split("-", 2)
            full_metric_name = "#{data}-#{metric}"

            if @define_metric
              define_metric(data, metric)
              EasyML::Loggers::Wandb.log({ full_metric_name => value })
            else
              EasyML::Loggers::Wandb.log({ full_metric_name => value })
            end
          end

          EasyML::Loggers::Wandb.log({ "epoch" => epoch })
          @define_metric = false
        end

        private

        def log_model_as_artifact(model)
          model_name = "#{EasyML::Loggers::Wandb.current_run.id}_model.json"
          model_path = File.join(EasyML::Loggers::Wandb.current_run.dir, model_name)
          model.save_model(model_path)

          model_artifact = EasyML::Loggers::Wandb.Artifact(name: model_name, type: "model")
          model_artifact.add_file(model_path)
          EasyML::Loggers::Wandb.current_run.log_artifact(model_artifact)
        end

        def log_feature_importance(model)
          fi = model.score(importance_type: @importance_type)
          fi_data = fi.map { |k, v| [k, v] }

          table = EasyML::Loggers::Wandb.Table(data: fi_data, columns: %w[Feature Importance])
          bar_plot = EasyML::Loggers::Wandb.plot.bar(table, "Feature", "Importance", title: "Feature Importance")
          EasyML::Loggers::Wandb.log({ "Feature Importance" => bar_plot })
        end

        def define_metric(data, metric_name)
          full_metric_name = "#{data}-#{metric_name}"

          if metric_name.downcase.include?("loss") || MINIMIZE_METRICS.include?(metric_name.downcase)
            EasyML::Loggers::Wandb.define_metric(full_metric_name, summary: "min")
          elsif MAXIMIZE_METRICS.include?(metric_name.downcase)
            EasyML::Loggers::Wandb.define_metric(full_metric_name, summary: "max")
          end
        end
      end
    end
  end
end
