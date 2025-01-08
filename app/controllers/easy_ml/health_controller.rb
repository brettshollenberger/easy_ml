module EasyML
  class HealthController < ApplicationController
    # No authentication or CSRF checks for this action
    skip_before_action :verify_authenticity_token

    def up
      render json: { status: "OK" }, status: :ok
    end
  end
end
