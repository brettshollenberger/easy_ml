module EasyML
  class DatasetsController < ApplicationController
    def index
      render inertia: "pages/DatasetsPage", props: {
        constants: Dataset.constants,
        datasets: Dataset.all.map { |dataset| dataset_to_json(dataset) },
        datasources: Datasource.all.map { |datasource| datasource_to_json(datasource) }
      }
    end

    def new
      render inertia: "pages/NewDatasetPage", props: {
        constants: Dataset.constants,
        datasources: Datasource.all.map { |datasource| datasource_to_json(datasource) }
      }
    end

    def create
      dataset = Dataset.new(dataset_params.to_h)

      if dataset.save
        redirect_to easy_ml_datasets_path, notice: "Dataset was successfully created."
      else
        redirect_to new_easy_ml_dataset_path, alert: dataset.errors.full_messages.join(", ")
      end
    end

    private

    def dataset_to_json(dataset)
      DatasetSerializer.new(dataset).serializable_hash.dig(:data, :attributes)
    end

    def datasource_to_json(datasource)
      DatasourceSerializer.new(datasource).serializable_hash.dig(:data, :attributes)
    end

    def dataset_params
      params.require(:dataset).permit(
        :name,
        :description,
        :datasource_id,
        :target,
        drop_cols: [],
        preprocessing_steps: {
          training: {}
        },
        splitter: {
          date: %i[date_col months_test months_valid]
        }
      )
    end
  end
end
