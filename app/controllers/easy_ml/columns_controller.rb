# == Schema Information
#
# Table name: easy_ml_columns
#
#  id                  :bigint           not null, primary key
#  dataset_id          :bigint           not null
#  name                :string           not null
#  description         :string
#  datatype            :string
#  polars_datatype     :string
#  preprocessing_steps :json
#  is_target           :boolean
#  hidden              :boolean          default(FALSE)
#  drop_if_null        :boolean          default(FALSE)
#  sample_values       :json
#  statistics          :json
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
module EasyML
  class ColumnsController < ApplicationController
    def update
      @column = EasyML::Column.find(params[:id])

      if @column.update(column_params)
        head :ok
      else
        render json: { errors: @column.errors }, status: :unprocessable_entity
      end
    end

    private

    def column_params
      params.require(:column).permit(:hidden)
    end
  end
end
