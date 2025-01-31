module EasyML
  class APIsController < ApplicationController
    def show
      model = EasyML::Model.find_by!(slug: params[:model])
      render json: { data: model.api_fields }
    end
  end
end
