# == Schema Information
#
# Table name: easy_ml_dataset_histories
#
#  id                      :bigint           not null, primary key
#  dataset_id              :integer          not null
#  name                    :string           not null
#  description             :string
#  dataset_type            :string
#  status                  :string
#  version                 :string
#  datasource_id           :integer
#  root_dir                :string
#  configuration           :json
#  num_rows                :integer
#  workflow_status         :string
#  statistics              :json
#  preprocessor_statistics :json
#  schema                  :json
#  refreshed_at            :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  history_started_at      :datetime         not null
#  history_ended_at        :datetime
#  history_user_id         :integer
#  snapshot_id             :string
#
module EasyML
  class DatasetHistory < ActiveRecord::Base
    include Historiographer::History

    def locked?
      true
    end
  end
end
