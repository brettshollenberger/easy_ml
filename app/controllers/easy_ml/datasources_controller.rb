# == Schema Information
#
# Table name: easy_ml_datasources
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  datasource_type :string
#  root_dir        :string
#  configuration   :json
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
module EasyML
  class DatasourcesController < ApplicationController
    def index
      @datasources = Datasource.all.order(id: :asc)
      render inertia: "pages/DatasourcesPage", props: {
        datasources: @datasources.map { |datasource| datasource_to_json(datasource) },
      }
    end

    def show
      @datasource = Datasource.find(params[:id])
      render json: @datasource, serializer: DatasourceSerializer
    end

    def edit
      datasource = EasyML::Datasource.find_by(id: params[:id])

      render inertia: "pages/DatasourceFormPage", props: {
        datasource: datasource_to_json(datasource),
        constants: EasyML::Datasource.constants,
      }
    end

    def new
      render inertia: "pages/DatasourceFormPage", props: {
        constants: EasyML::Datasource.constants,
      }
    end

    def create
      EasyML::Datasource.transaction do
        datasource = EasyML::Datasource.create!(datasource_params)
      end

      redirect_to easy_ml_datasources_path, notice: "Datasource was successfully created."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to new_easy_ml_datasource_path, alert: e.record.errors.full_messages.join(", ")
    end

    def destroy
      @datasource = Datasource.find(params[:id])
      @datasource.destroy

      redirect_to easy_ml_datasources_path, notice: "Datasource was successfully deleted."
    end

    def update
      datasource = EasyML::Datasource.find(params[:id])
      if datasource.update(datasource_params)
        redirect_to easy_ml_datasources_path, notice: "Datasource was successfully updated."
      else
        redirect_to edit_easy_ml_datasource_path(datasource), alert: datasource.errors.full_messages.join(", ")
      end
    end

    def sync
      datasource = Datasource.find(params[:id])
      datasource.update(is_syncing: true)

      Rails.logger.info("X-Forwarded-Host: #{request.headers["X-Forwarded-Host"]}")
      Rails.logger.info("X-Forwarded-Port: #{request.headers["X-Forwarded-Port"]}")

      # Start sync in background to avoid blocking
      datasource.refresh_async

      redirect_to easy_ml_datasources_path, notice: "Datasource is syncing..."
    rescue ActiveRecord::RecordNotFound
      redirect_to easy_ml_datasources_path, error: "Datasource not found..."
    end

    def abort
      datasource = Datasource.find(params[:id])
      datasource.abort!

      redirect_to easy_ml_datasources_path, notice: "Datasource sync has been aborted."
    end

    private

    def datasource_params
      params.require(:datasource).permit(:name, :s3_bucket, :s3_prefix, :s3_region, :datasource_type).merge!(
        datasource_type: "s3",
      )
    end
  end
end
