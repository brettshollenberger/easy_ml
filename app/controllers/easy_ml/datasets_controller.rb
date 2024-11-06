# == Schema Information
#
# Table name: easy_ml_datasets
#
#  id            :bigint           not null, primary key
#  name          :string           not null
#  description   :string
#  dataset_type  :string
#  status        :string
#  version       :string
#  datasource_id :bigint
#  root_dir      :string
#  configuration :json
#  num_rows      :bigint
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
module EasyML
  class DatasetsController < ApplicationController
    def index
      datasets = Dataset.all

      render inertia: "pages/DatasetsPage", props: {
        datasets: datasets.map { |dataset| dataset_to_json(dataset) },
        constants: Dataset.constants
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
        dataset.refresh_async
        redirect_to easy_ml_datasets_path, notice: "Dataset was successfully created."
      else
        redirect_to new_easy_ml_dataset_path, alert: dataset.errors.full_messages.join(", ")
      end
    end

    def destroy
      dataset = Dataset.find(params[:id])

      if dataset.destroy
        redirect_to easy_ml_datasets_path, notice: "Dataset was successfully deleted."
      else
        redirect_to easy_ml_datasets_path, alert: "Failed to delete dataset."
      end
    end

    private

    def dataset_to_json(dataset)
      {
        id: dataset.id,
        name: dataset.name,
        description: dataset.description,
        columns: dataset.columns,
        num_rows: dataset.num_rows,
        status: dataset.status
      }
    end

    def datasource_to_json(datasource)
      DatasourceSerializer.new(datasource).serializable_hash.dig(:data, :attributes)
    end

    def dataset_params
      params.require(:dataset).permit(
        :name,
        :root_dir,
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
      ).merge!(
        root_dir: EasyML::Datasource.find_by(id: params.dig(:dataset, :datasource_id)).root_dir
      )
    end
  end
end
