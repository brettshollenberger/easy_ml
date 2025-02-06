# == Schema Information
#
# Table name: easy_ml_datasets
#
#  id                      :bigint           not null, primary key
#  name                    :string           not null
#  description             :string
#  dataset_type            :string
#  status                  :string
#  version                 :string
#  datasource_id           :bigint
#  root_dir                :string
#  configuration           :json
#  num_rows                :bigint
#  workflow_status         :string
#  statistics              :json
#  preprocessor_statistics :json
#  schema                  :json
#  refreshed_at            :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
module EasyML
  class DatasetsController < ApplicationController
    def index
      datasets = Dataset.all.order(id: :desc)

      render inertia: "pages/DatasetsPage", props: {
        datasets: datasets.map { |dataset| dataset_to_json_small(dataset) },
        constants: Dataset.constants,
      }
    end

    def new
      render inertia: "pages/NewDatasetPage", props: {
        constants: Dataset.constants,
        datasources: Datasource.all.map { |datasource| datasource_to_json(datasource) },
      }
    end

    def create
      EasyML::Datasource.find_by(id: params.dig(:dataset, :datasource_id))
      dataset = Dataset.new(dataset_params.to_h)

      if dataset.save
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

    def show
      dataset = Dataset.find(params[:id])

      render inertia: "pages/DatasetDetailsPage", props: {
        dataset: dataset_to_json(dataset),
        constants: Dataset.constants,
      }
    end

    def update
      dataset = Dataset.find(params[:id])

      # Iterate over columns to check and update preprocessing_steps
      dataset_params[:columns_attributes]&.each do |_, column_attrs|
        column_attrs[:preprocessing_steps] = nil if column_attrs.dig(:preprocessing_steps, :training, :method) == "none"
      end

      if dataset.update(dataset_params)
        flash.now[:notice] = "Dataset configuration was successfully updated."
        render inertia: "pages/DatasetDetailsPage", props: {
          dataset: dataset_to_json(dataset),
          constants: Dataset.constants,
        }
      else
        flash.now[:error] = dataset.errors.full_messages.join(", ")
        render inertia: "pages/DatasetDetailsPage", props: {
          dataset: dataset_to_json(dataset),
          constants: Dataset.constants,
        }
      end
    end

    def refresh
      dataset = Dataset.find(params[:id])
      dataset.refresh_async

      redirect_to easy_ml_datasets_path, notice: "Dataset refresh has been initiated."
    end

    private

    def preprocessing_params
      [:method, { params: [:constant, :categorical_min, :one_hot, :ordinal_encoding, { clip: %i[min max] }] }]
    end

    def dataset_params
      params.require(:dataset).permit(
        :name,
        :description,
        :datasource_id,
        :target,
        drop_cols: [],
        splitter_attributes: %i[
          splitter_type
          date_col
          months_test
          months_valid
          train_ratio
          test_ratio
          valid_ratio
          train_files
          test_files
          valid_files
        ],
        columns_attributes: [
          :id,
          :name,
          :type,
          :description,
          :datatype,
          :polars_datatype,
          :is_target,
          :is_date_column,
          :hidden,
          :drop_if_null,
          :sample_values,
          :_destroy,
          {
            preprocessing_steps: {
              training: preprocessing_params,
              inference: preprocessing_params,
            },
            statistics: %i[mean median min max null_count],
          },
        ],
        features_attributes: %i[
          id
          name
          feature_class
          feature_position
          _destroy
        ],
      )
    end
  end
end
