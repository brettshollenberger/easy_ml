module EasyML
  class RetrainingRunsController < ApplicationController
    def index
      model = EasyML::Model.find(params[:id])
      limit = (params[:limit] || 20).to_i
      offset = (params[:offset] || 0).to_i

      render json: ModelSerializer.new(
        model,
        params: { limit: limit, offset: offset },
      ).serializable_hash
    end

    def show
      run = EasyML::RetrainingRun.find(params[:id])
      render json: RetrainingRunSerializer.new(run).serializable_hash
    end
  end
end
