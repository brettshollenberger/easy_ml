require "action_controller"
module EasyML
  class ApplicationController < ActionController::Base
    helper EasyML::ApplicationHelper

    include InertiaRails::Controller
    layout "easy_ml/application"

    protect_from_forgery with: :exception

    def easy_ml_root
      Rails.application.routes.routes.find { |r| r.app.app == EasyML::Engine }&.path&.spec&.to_s
    end

    inertia_share do
      flash_messages = []

      flash_messages << { type: "success", message: flash[:notice] } if flash[:notice]

      flash_messages << { type: "error", message: flash[:alert] } if flash[:alert]

      flash_messages << { type: "info", message: flash[:info] } if flash[:info]

      {
        rootPath: easy_ml_root,
        url: request.path.gsub(Regexp.new(easy_ml_root), ""),
        errors: session.delete(:errors) || {},
        flash: flash_messages
      }
    end
  end
end
