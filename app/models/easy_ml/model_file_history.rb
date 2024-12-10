# == Schema Information
#
# Table name: easy_ml_model_file_histories
#
#  id                 :bigint           not null, primary key
#  model_file_id      :integer          not null
#  filename           :string           not null
#  path               :string           not null
#  configuration      :json
#  model_type         :string
#  model_id           :integer
#  retraining_run_id  :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  deployed_at        :datetime
#  deployed           :boolean
#  history_started_at :datetime         not null
#  history_ended_at   :datetime
#  history_user_id    :integer
#  snapshot_id        :string
#
module EasyML
  class ModelFileHistory < ActiveRecord::Base
    self.table_name = "easy_ml_model_file_histories"
    include Historiographer::History
  end
end
