# == Schema Information
#
# Table name: easy_ml_feature_histories
#
#  id                 :bigint           not null, primary key
#  feature_id         :integer          not null
#  dataset_id         :integer          not null
#  name               :string
#  version            :integer
#  feature_class      :string           not null
#  feature_method     :string           not null
#  feature_position   :integer
#  applied_at         :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  history_started_at :datetime         not null
#  history_ended_at   :datetime
#  history_user_id    :integer
#  snapshot_id        :string
#
module EasyML
  class FeatureHistory < ActiveRecord::Base
    self.table_name = "easy_ml_feature_histories"
    include Historiographer::History
  end
end
