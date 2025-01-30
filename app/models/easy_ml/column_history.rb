# == Schema Information
#
# Table name: easy_ml_column_histories
#
#  id                  :bigint           not null, primary key
#  column_id           :integer          not null
#  dataset_id          :integer          not null
#  name                :string           not null
#  description         :string
#  datatype            :string
#  polars_datatype     :string
#  is_target           :boolean
#  hidden              :boolean          default(FALSE)
#  drop_if_null        :boolean          default(FALSE)
#  preprocessing_steps :json
#  sample_values       :json
#  statistics          :json
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  history_started_at  :datetime         not null
#  history_ended_at    :datetime
#  history_user_id     :integer
#  snapshot_id         :string
#  is_date_column      :boolean          default(FALSE)
#
module EasyML
  class ColumnHistory < ActiveRecord::Base
    self.table_name = "easy_ml_column_histories"
    include Historiographer::History
  end
end
