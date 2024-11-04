require_relative "../../options/datasource_options"
module EasyML
  class DatasourcesController < ApplicationController
    def index
      datasources = EasyML::Datasource.s3

      render inertia: "pages/DatasourcesPage", props: {
        datasources: datasources.map do |datasource|
          {
            id: datasource.id,
            name: datasource.name,
            datasource_type: datasource.datasource_type,
            configuration: {
              s3_bucket: datasource.configuration["s3_bucket"],
              s3_prefix: datasource.configuration["s3_prefix"],
              s3_region: datasource.configuration["s3_region"]
            },
            created_at: datasource.created_at,
            updated_at: datasource.updated_at
          }
        end
      }
    end

    def edit
      EasyML::Datasource.find_by(id: params["id"])
    end

    def new
      render inertia: "pages/NewDatasourcePage", props: {
        constants: EasyML::DatasourceOptions.constants
      }
    end

    def create
      EasyML::Datasource.create!(datasource_params)

      redirect_to easy_ml_datasources_path, notice: "Datasource was successfully created."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to new_easy_ml_datasource_path, alert: e.record.errors.full_messages.join(", ")
    end

    def destroy
      @datasource = Datasource.find(params[:id])
      @datasource.destroy

      redirect_to easy_ml_datasources_path, notice: "Datasource was successfully deleted."
    end

    private

    def datasource_params
      params.require(:datasource).permit(:name, :s3_bucket, :s3_prefix, :s3_region, :datasource_type, :s3_access_key_id, :s3_secret_access_key, :root_dir).merge!(
        datasource_type: :s3,
        s3_access_key_id: EasyML::Configuration.s3_access_key_id,
        s3_secret_access_key: EasyML::Configuration.s3_secret_access_key,
        root_dir: Rails.root.join("datasets")
      )
    end
  end
end
