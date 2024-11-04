module EasyML
  class DatasourcesController < ApplicationController
    def index
      datasources = EasyML::Datasource.where(datasource_type: :s3)

      render inertia: "pages/DatasourcesPage", props: {
        datasources: datasources.map(&:as_json)
      }
    end

    def new
      render inertia: "pages/NewDatasourcePage", props: {}
    end

    def create
      EasyML::Datasource.create!(datasource_params)

      redirect_to easy_ml_datasources_path, notice: "Datasource was successfully created."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to new_easy_ml_datasource_path, alert: e.record.errors.full_messages.join(", ")
    end

    private

    def datasource_params
      params.require(:datasource).permit(:name, :s3_bucket, :s3_prefix, :s3_region, :datasource_type, :s3_access_key_id, :s3_secret_access_key).merge!(
        datasource_type: :s3,
        s3_access_key_id: EasyML::Configuration.s3_access_key_id,
        s3_secret_access_key: EasyML::Configuration.s3_secret_access_key
      )
    end
  end
end
