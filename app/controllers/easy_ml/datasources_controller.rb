require_relative "../../options/datasource_options"
module EasyML
  class DatasourcesController < ApplicationController
    def index
      @datasources = Datasource.all.order(id: :asc)
      render inertia: "pages/DatasourcesPage", props: {
        datasources: @datasources.map { |datasource| to_json(datasource) }
      }
    end

    def show
      @datasource = Datasource.find(params[:id])
      render json: @datasource, serializer: DatasourceSerializer
    end

    def edit
      datasource = EasyML::Datasource.find_by(id: params[:id])

      render inertia: "pages/DatasourceFormPage", props: {
        datasource: to_json(datasource),
        constants: EasyML::DatasourceOptions.constants
      }
    end

    def new
      render inertia: "pages/DatasourceFormPage", props: {
        constants: EasyML::DatasourceOptions.constants
      }
    end

    def create
      datasource = EasyML::Datasource.create!(datasource_params)
      datasource.update(is_syncing: true, root_dir: root_dir_name(datasource))
      EasyML::SyncDatasourceWorker.perform_async(datasource.id)

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

      # Start sync in background to avoid blocking
      EasyML::SyncDatasourceWorker.perform_async(datasource.id)

      redirect_to easy_ml_datasources_path, notice: "Datasource is syncing..."
    rescue ActiveRecord::RecordNotFound
      redirect_to easy_ml_datasources_path, error: "Datasource not found..."
    end

    private

    def root_dir_name(datasource)
      datasource_folder = datasource.name.gsub(/\s{2,}/, " ").split(" ").join("_").downcase
      Rails.root.join("easy_ml/datasets").join(datasource_folder)
    end

    def datasource_params
      params.require(:datasource).permit(:name, :s3_bucket, :s3_prefix, :s3_region, :datasource_type, :s3_access_key_id, :s3_secret_access_key, :root_dir).merge!(
        datasource_type: :s3,
        s3_access_key_id: EasyML::Configuration.s3_access_key_id,
        s3_secret_access_key: EasyML::Configuration.s3_secret_access_key
      )
    end

    def to_json(datasource)
      DatasourceSerializer.new(datasource).serializable_hash.dig(:data, :attributes)
    end
  end
end
