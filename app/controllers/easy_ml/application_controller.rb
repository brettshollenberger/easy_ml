require "action_controller"

module EasyML
  class ApplicationController < ActionController::Base
    helper EasyML::ApplicationHelper

    include InertiaRails::Controller
    layout "easy_ml/application"

    protect_from_forgery with: :exception

    before_action :hot_reload

    def hot_reload
      return unless Rails.env.development? && ENV["EASY_ML_DEV"]

      Dir[EasyML::Engine.root.join("lib/**/*")].select { |f| Pathname.new(f).extname == ".rb" }.each do |file|
        load file
      end
    end

    def settings_to_json(settings)
      SettingsSerializer.new(settings).serializable_hash.dig(:data, :attributes)
    end

    def dataset_to_json(dataset)
      DatasetSerializer.new(dataset).serializable_hash.dig(:data, :attributes)
    end

    def datasource_to_json(datasource)
      DatasourceSerializer.new(datasource).serializable_hash.dig(:data, :attributes)
    end

    def model_to_json(model)
      ModelSerializer.new(model).serializable_hash.dig(:data, :attributes)
    end

    def retraining_job_to_json(job)
      RetrainingJobSerializer.new(job).serializable_hash.dig(:data, :attributes)
    end

    def retraining_run_to_json(run)
      RetrainingRunSerializer.new(run).serializable_hash.dig(:data, :attributes)
    end

    def easy_ml_root
      Rails.application.routes.routes.find { |r| r.app.app == EasyML::Engine }&.path&.spec&.to_s
    end

    inertia_share do
      flash_messages = []

      flash_messages << { type: "success", message: flash[:notice] } if flash[:notice]

      flash_messages << { type: "error", message: flash[:error] } if flash[:error]

      flash_messages << { type: "info", message: flash[:info] } if flash[:info]

      {
        rootPath: easy_ml_root,
        url: request.path.gsub(Regexp.new(easy_ml_root), ""),
        errors: session.delete(:errors) || {},
        flash: flash_messages,
      }
    end
  end
end
