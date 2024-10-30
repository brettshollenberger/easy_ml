module EasyML
  class ApplicationController < ActionController::Base
    helper EasyML::ApplicationHelper

    include InertiaRails::Controller
    layout "easy_ml/application"

    protect_from_forgery with: :exception

    private

    def inertia_share
      {
        errors: session.delete(:errors) || {},
        flash: {
          success: flash.notice,
          error: flash.alert
        }.compact
      }
    end
  end
end
