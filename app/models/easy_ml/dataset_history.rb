# == Schema Information
#
# Table name: easy_ml_dataset_histories
#
#  id                  :bigint           not null, primary key
#  dataset_id          :integer          not null
#  name                :string           not null
#  description         :string
#  dataset_type        :string
#  status              :string
#  version             :string
#  datasource_id       :integer
#  root_dir            :string
#  configuration       :json
#  num_rows            :integer
#  workflow_status     :string
#  statistics          :json
#  schema              :json
#  refreshed_at        :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  history_started_at  :datetime         not null
#  history_ended_at    :datetime
#  history_user_id     :integer
#  snapshot_id         :string
#  last_datasource_sha :string
#  raw_schema          :jsonb
#
module EasyML
  class DatasetHistory < ActiveRecord::Base
    self.table_name = "easy_ml_dataset_histories"
    include Historiographer::History

    has_many :columns, ->(dataset_history) { where(snapshot_id: dataset_history.snapshot_id) },
      class_name: "EasyML::ColumnHistory",
      foreign_key: "dataset_id",
      primary_key: "dataset_id",
      extend: EasyML::ColumnList

    def fit
      false
    end

    def processed?
      true
    end

    def needs_refresh?
      false
    end
  end
end
