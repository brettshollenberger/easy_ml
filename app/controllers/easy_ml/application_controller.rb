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
      {
        rootPath: easy_ml_root,
        url: request.path.gsub(Regexp.new(easy_ml_root), ""),
        errors: session.delete(:errors) || {},
        flash: {
          success: flash.notice,
          error: flash.alert
        }.compact
      }
    end
  end
end
