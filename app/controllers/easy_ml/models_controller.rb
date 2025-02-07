# == Schema Information
#
# Table name: easy_ml_models
#
#  id            :bigint           not null, primary key
#  name          :string           not null
#  model_type    :string
#  status        :string
#  dataset_id    :bigint
#  configuration :json
#  version       :string           not null
#  root_dir      :string
#  file          :json
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
module EasyML
  class ModelsController < ApplicationController
    include EasyML::Engine.routes.url_helpers

    def index
      models = EasyML::Model.all.includes(includes_list).order(:last_trained_at, :id)

      render inertia: "pages/ModelsPage", props: {
        models: models.map { |model| model_to_json(model) },
      }
    end

    def new
      render inertia: "pages/NewModelPage", props: {
        datasets: EasyML::Dataset.all.map do |dataset|
          dataset.slice(:id, :name, :num_rows)
        end,
        constants: EasyML::Model.constants,
      }
    end

    def edit
      model = Model.includes(includes_list).find(params[:id])
      render inertia: "pages/EditModelPage", props: {
        model: model_to_json(model),
        datasets: EasyML::Dataset.all.map do |dataset|
          dataset.slice(:id, :name, :num_rows)
        end,
        constants: EasyML::Model.constants,
      }
    end

    def create
      model = Model.new(model_params)

      if model.save
        flash[:notice] = "Model was successfully created."
        redirect_to easy_ml_models_path
      else
        errors = model.errors.to_hash(true)
        values = errors.values.flatten
        flash.now[:error] = values.join(", ")
        render inertia: "pages/NewModelPage", props: {
          datasets: EasyML::Dataset.all.map do |dataset|
            dataset.slice(:id, :name, :num_rows)
          end,
          constants: EasyML::Model.constants,
          errors: model.errors.to_hash(true),
        }
      end
    end

    def update
      model = Model.find(params[:id])

      if model.update(model_params)
        flash[:notice] = "Model was successfully updated."
        redirect_to easy_ml_models_path
      else
        errors = model.errors.to_hash(true)
        values = errors.values.flatten
        flash.now[:error] = values.join(", ")
        render inertia: "pages/EditModelPage", props: {
          model: model_to_json(model),
          datasets: EasyML::Dataset.all.map { |dataset| dataset_to_json(dataset) },
          constants: EasyML::Model.constants,
          errors: model.errors.to_hash(true),
        }
      end
    end

    def show
      model = Model.includes(includes_list)
                   .find(params[:id])

      if request.format.json?
        render json: { model: model_to_json(model) }
      else
        render inertia: "pages/ShowModelPage", props: {
                 model: model_to_json(model),
               }
      end
    end

    def destroy
      model = Model.find(params[:id])

      if model.destroy
        flash[:notice] = "Model was successfully deleted."
        redirect_to easy_ml_models_path
      else
        flash[:error] = "Failed to delete the model."
        redirect_to easy_ml_models_path
      end
    end

    def train
      model = EasyML::Model.find(params[:id])
      model.train
      flash[:notice] = "Model training started!"

      redirect_to easy_ml_models_path
    end

    def abort
      model = Model.find(params[:id])
      model.abort!

      flash[:notice] = "Model training aborted!"
      redirect_to easy_ml_models_path
    end

    private

    def includes_list
      [:retraining_runs, :retraining_job, dataset: [:columns, :features, :splitter]]
    end

    def model_params
      params.require(:model).permit(
        :name,
        :model_type,
        :dataset_id,
        :task,
        :objective,
        metrics: [],
        retraining_job_attributes: [
          :id,
          :frequency,
          :active,
          :metric,
          :direction,
          :threshold,
          :tuning_frequency,
          :batch_mode,
          :batch_size,
          :batch_overlap,
          :batch_key,
          :tuning_enabled,
          at: [:hour, :day_of_week, :day_of_month],
          tuner_config: [
            :n_trials,
            config: {},
          ],
        ],
      )
    end
  end
end
