# == Schema Information
#
# Table name: easy_ml_model_histories
#
#  id                 :bigint           not null, primary key
#  model_id           :integer          not null
#  name               :string           not null
#  model_type         :string
#  status             :string
#  dataset_id         :integer
#  configuration      :json
#  version            :string           not null
#  root_dir           :string
#  file               :json
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  history_started_at :datetime         not null
#  history_ended_at   :datetime
#  history_user_id    :integer
#  snapshot_id        :string
#
module EasyML
  module Models
    class XGBoostHistory < ModelHistory
      self.table_name = "easy_ml_model_histories"
      self.inheritance_column = :model_type
      include Historiographer::History
    end
  end
end