module EasyML
  class DeploysController < ApplicationController
    def create
      run = EasyML::RetrainingRun.find(params[:retraining_run_id])
      run.update(is_deploying: true)
      @deploy = EasyML::Deploy.create!(
        model_id: params[:easy_ml_model_id],
        retraining_run_id: params[:retraining_run_id],
        trigger: "manual",
      )

      @deploy.deploy

      flash[:notice] = "Model deployment has started"
      redirect_to easy_ml_model_path(@deploy.model)
    rescue => e
      flash[:alert] = "Trouble deploying model: #{e.message}"
      redirect_to easy_ml_model_path(@deploy.model)
    end
  end
end
